USE WSN_Analytics;
GO

--Query 1: Energy Consumption Audit by Zone and Day

SELECT
    dz.ZoneName,
    dd.[Year],
    dd.MonthName,
    dd.FullDate                              AS ReadingDate,
    COUNT(*)                                 AS TotalReadings,
    SUM(CASE WHEN f.IsKernelNode = 1
             THEN 1 ELSE 0 END)              AS KernelNodeReadings,
    SUM(f.EnergyConsumedNJ)                  AS TotalEnergy_NJ,
    AVG(f.EnergyConsumedNJ)                  AS AvgEnergyPerReading_NJ,
    MAX(f.EnergyConsumedNJ)                  AS PeakEnergy_NJ,
    -- Energy saved vs full transmission (estimated 100% baseline)
    ROUND(
        100.0 * (1.0 - COUNT(CASE WHEN f.IsKernelNode=1 THEN 1 END)
                      * 1.0 / COUNT(*)),
    2)                                       AS EstimatedEnergySavingPct
FROM fact_KernelReading    f
JOIN dim_SensorNode        n  ON n.NodeID  = f.NodeID
JOIN dim_DeploymentZone    dz ON dz.ZoneID = n.ZoneID
JOIN dim_Date              dd ON dd.DateKey = f.DateKey
GROUP BY
    dz.ZoneName, dd.[Year], dd.MonthName, dd.FullDate
ORDER BY
    dd.FullDate, dz.ZoneName;
GO


-- Q2: Hourly temperature trend with 3-hour rolling average per zone
WITH HourlyAgg AS (
    SELECT
        dz.ZoneID,
        dz.ZoneName,
        DATEADD(HOUR,
            DATEDIFF(HOUR, 0, f.ReadingTime), 0)  AS HourBucket,
        AVG(f.TemperatureC)                       AS HourlyAvgTemp,
        AVG(f.HumidityPct)                        AS HourlyAvgHumidity,
        COUNT(*)                                  AS Readings
    FROM fact_KernelReading    f
    JOIN dim_SensorNode        n  ON n.NodeID  = f.NodeID
    JOIN dim_DeploymentZone    dz ON dz.ZoneID = n.ZoneID
    WHERE f.TemperatureC IS NOT NULL
    GROUP BY dz.ZoneID, dz.ZoneName,
             DATEADD(HOUR, DATEDIFF(HOUR,0,f.ReadingTime),0)
)
SELECT
    ZoneName,
    HourBucket,
    ROUND(HourlyAvgTemp, 2)                      AS HourlyAvgTemp_C,
    ROUND(HourlyAvgHumidity, 2)                  AS HourlyAvgHumidity_Pct,
    ROUND(AVG(HourlyAvgTemp) OVER (
        PARTITION BY ZoneID
        ORDER BY HourBucket
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                        AS RollingAvg3H_C,
    Readings
FROM HourlyAgg
ORDER BY ZoneName, HourBucket;
GO


-- Q3: Epsilon approximation quality report — distribution and threshold violations
WITH grouped_data AS (
    SELECT
        n.NodeID,
        n.NodeCode,
        dz.ZoneName,
        COUNT(*)                               AS TotalReadings,
        ROUND(AVG(f.EpsilonBound), 5)          AS AvgEpsilon,
        ROUND(MIN(f.EpsilonBound), 5)          AS MinEpsilon,
        ROUND(MAX(f.EpsilonBound), 5)          AS MaxEpsilon,
        SUM(CASE WHEN f.EpsilonBound > 0.0200
                 THEN 1 ELSE 0 END)            AS ViolationCount,
        ROUND(100.0 * SUM(CASE WHEN f.EpsilonBound > 0.0200
                               THEN 1 ELSE 0 END) / COUNT(*), 1) AS ViolationPct
    FROM fact_KernelReading    f
    JOIN dim_SensorNode        n  ON n.NodeID  = f.NodeID
    JOIN dim_DeploymentZone    dz ON dz.ZoneID = n.ZoneID
    GROUP BY n.NodeID, n.NodeCode, dz.ZoneName
),
percentiles AS (
    SELECT DISTINCT
        n.NodeID,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY f.EpsilonBound)
            OVER (PARTITION BY n.NodeID) AS P95_Epsilon
    FROM fact_KernelReading f
    JOIN dim_SensorNode n ON n.NodeID = f.NodeID
)
SELECT 
    g.NodeCode,
    g.ZoneName,
    g.TotalReadings,
    g.AvgEpsilon,
    g.MinEpsilon,
    g.MaxEpsilon,
    g.ViolationCount,
    g.ViolationPct,
    ROUND(p.P95_Epsilon, 5) AS P95_Epsilon
FROM grouped_data g
LEFT JOIN percentiles p ON g.NodeID = p.NodeID
ORDER BY g.AvgEpsilon DESC;


-- Q4: Battery health report and estimated remaining rounds per node
WITH LatestBattery AS (
    SELECT NodeID,
           BatteryLevelPct,
           EnergyConsumedNJ,
           ReadingTime,
           ROW_NUMBER() OVER (
               PARTITION BY NodeID
               ORDER BY ReadingTime DESC
           ) AS rn
    FROM fact_KernelReading
    WHERE BatteryLevelPct IS NOT NULL
),
NodeAvgEnergy AS (
    SELECT NodeID,
           AVG(EnergyConsumedNJ) AS AvgEnergyPerRound_NJ
    FROM fact_KernelReading
    WHERE EnergyConsumedNJ IS NOT NULL
    GROUP BY NodeID
)
SELECT
    n.NodeCode,
    dz.ZoneName,
    ROUND(lb.BatteryLevelPct, 1)           AS CurrentBattery_Pct,
    n.BatteryCapacityMAh,
    ROUND(ae.AvgEnergyPerRound_NJ, 2)      AS AvgEnergyPerRound_NJ,
    -- Estimate remaining charge in nJ (1 mAh at 3.3V ≈ 11,880,000 nJ)
    ROUND(
        n.BatteryCapacityMAh * 11880000.0 * lb.BatteryLevelPct / 100.0
        / ae.AvgEnergyPerRound_NJ,
    0)                                     AS EstimatedRoundsLeft,
    CASE
        WHEN lb.BatteryLevelPct < 20 THEN 'CRITICAL'
        WHEN lb.BatteryLevelPct < 40 THEN 'WARNING'
        ELSE 'OK'
    END                                    AS BatteryStatus,
    lb.ReadingTime                         AS LastSeen
FROM LatestBattery          lb
JOIN NodeAvgEnergy          ae ON ae.NodeID = lb.NodeID
JOIN dim_SensorNode         n  ON n.NodeID  = lb.NodeID
JOIN dim_DeploymentZone     dz ON dz.ZoneID = n.ZoneID
WHERE lb.rn = 1
ORDER BY lb.BatteryLevelPct ASC;
GO


-- Q5: Executive dashboard — zone-level kernel efficiency ratio and KPIs
WITH ZoneMetrics AS (
    SELECT
        n.ZoneID,
        COUNT(*)                           AS TotalReadings,
        SUM(CASE WHEN f.IsKernelNode = 1
                 THEN 1 ELSE 0 END)        AS KernelReadings,
        SUM(f.EnergyConsumedNJ)            AS TotalEnergy_NJ,
        AVG(f.TemperatureC)                AS OverallAvgTemp_C,
        AVG(f.HumidityPct)                 AS OverallAvgHumidity,
        AVG(f.EpsilonBound)                AS AvgEpsilon,
        AVG(f.BatteryLevelPct)             AS AvgBattery_Pct,
        COUNT(DISTINCT f.NodeID)           AS ActiveNodes
    FROM fact_KernelReading f
    JOIN dim_SensorNode     n ON n.NodeID = f.NodeID
    GROUP BY n.ZoneID
)
SELECT
    dz.ZoneName,
    dz.ZoneType,
    zm.ActiveNodes,
    zm.TotalReadings,
    zm.KernelReadings,
    ROUND(100.0 * zm.KernelReadings
          / NULLIF(zm.TotalReadings, 0), 1) AS KernelEfficiencyRatio_Pct,
    ROUND(zm.TotalEnergy_NJ / 1000.0, 3)    AS TotalEnergy_uJ,
    ROUND(zm.OverallAvgTemp_C, 2)            AS AvgTemp_C,
    ROUND(zm.OverallAvgHumidity, 2)          AS AvgHumidity_Pct,
    ROUND(zm.AvgEpsilon, 5)                  AS AvgApproxQuality,
    ROUND(zm.AvgBattery_Pct, 1)              AS AvgBattery_Pct,
    -- Composite health score (0–100)
    ROUND(
        (zm.AvgBattery_Pct * 0.4)            -- 40% weight: battery
      + ((1 - zm.AvgEpsilon) * 100 * 0.3)   -- 30% weight: accuracy
      + (100.0 * zm.KernelReadings
             / NULLIF(zm.TotalReadings,0)     
             * 0.3),                          -- 30% weight: efficiency
    1)                                        AS NetworkHealthScore
FROM ZoneMetrics            zm
JOIN dim_DeploymentZone     dz ON dz.ZoneID = zm.ZoneID
ORDER BY NetworkHealthScore DESC;
GO