USE master;
-- 1. Create the database
CREATE DATABASE WSN_Analytics;
GO
USE WSN_Analytics;
GO

-- 2. Dimension tables
CREATE TABLE dim_DeploymentZone (
    ZoneID    INT IDENTITY(1,1) PRIMARY KEY,
    ZoneName  VARCHAR(80)  NOT NULL,
    ZoneType  VARCHAR(30)  NOT NULL
);

CREATE TABLE dim_SensorNode (
    NodeID          INT IDENTITY(1,1) PRIMARY KEY,
    NodeCode        VARCHAR(20) NOT NULL UNIQUE,
    ZoneID          INT NOT NULL REFERENCES dim_DeploymentZone(ZoneID),
    Latitude        DECIMAL(9,6) NOT NULL,
    Longitude       DECIMAL(9,6) NOT NULL,
    BatteryCapacityMAh INT NOT NULL DEFAULT 3000,
    IsKernelCapable BIT NOT NULL DEFAULT 1
);

CREATE TABLE dim_Date (
    DateKey  INT  PRIMARY KEY,
    FullDate DATE NOT NULL UNIQUE,
    [Year]   SMALLINT, [Month] TINYINT, MonthName VARCHAR(10)
);

-- 3. Fact table
CREATE TABLE fact_KernelReading (
    ReadingID        BIGINT IDENTITY(1,1) PRIMARY KEY,
    NodeID           INT NOT NULL REFERENCES dim_SensorNode(NodeID),
    DateKey          INT NOT NULL REFERENCES dim_Date(DateKey),
    ReadingTime      DATETIME2(3) NOT NULL,
    TemperatureC     DECIMAL(6,2),
    HumidityPct      DECIMAL(5,2),
    PressureHPa      DECIMAL(7,2),
    IsKernelNode     BIT NOT NULL DEFAULT 1,
    EpsilonBound     DECIMAL(7,5) NOT NULL,
    HopCount         TINYINT DEFAULT 1,
    EnergyConsumedNJ DECIMAL(10,4),
    BatteryLevelPct  DECIMAL(5,2)
);
GO


--insert into

-- Zones
INSERT INTO dim_DeploymentZone (ZoneName, ZoneType) VALUES
    ('Forest Sector A',     'Environmental'),
    ('Industrial Plant B',  'Industrial'),
    ('Urban Campus C',      'Smart City');

-- Nodes
INSERT INTO dim_SensorNode
    (NodeCode, ZoneID, Latitude, Longitude, BatteryCapacityMAh, IsKernelCapable)
VALUES
    ('NODE-001', 1, 37.6801, -122.0841, 3000, 1),
    ('NODE-002', 1, 37.6839, -122.0879, 3000, 1),
    ('NODE-003', 1, 37.6815, -122.0902, 3000, 0),
    ('NODE-004', 2, 37.7031, -122.1401, 5000, 1),
    ('NODE-005', 2, 37.7068, -122.1439, 5000, 1),
    ('NODE-006', 2, 37.7045, -122.1455, 5000, 0),
    ('NODE-007', 3, 37.3365, -121.8845, 2500, 1),
    ('NODE-008', 3, 37.3401, -121.8871, 2500, 1),
    ('NODE-009', 3, 37.3378, -121.8898, 2500, 0),
    ('NODE-010', 3, 37.3355, -121.8820, 2500, 1);

-- Date dimension (just the dates you need)
TRUNCATE TABLE fact_KernelReading;
INSERT INTO dim_Date (DateKey, FullDate, [Year], [Month], MonthName) VALUES
    (20260501, '2026-05-01', 2026, 5, 'May'),
    (20260502, '2026-05-02', 2026, 5, 'May');

-- Fact rows (your 20 kernel readings)
TRUNCATE TABLE fact_KernelReading;
INSERT INTO fact_KernelReading
    (NodeID, DateKey, ReadingTime, TemperatureC, HumidityPct,
     PressureHPa, IsKernelNode, EpsilonBound, HopCount,
     EnergyConsumedNJ, BatteryLevelPct)
VALUES
-- Round 1
(1, 20260501, '2026-05-01 08:00:00', 22.4, 65.3, 1013.2, 1, 0.01000, 1, 184.50, 92.5),
(2, 20260501, '2026-05-01 08:00:05', 21.9, 67.1, 1013.5, 1, 0.01000, 1, 178.20, 88.3),
(3, 20260501, '2026-05-01 08:00:10', 23.1, 63.8, 1012.9, 0, 0.01000, 2, 201.60, 95.1),
(4, 20260501, '2026-05-01 08:00:03', 38.7, 42.0, 1010.1, 1, 0.01500, 1, 312.40, 76.8),
(5, 20260501, '2026-05-01 08:00:08', 39.2, 40.5, 1009.8, 1, 0.01500, 1, 318.90, 74.2),
(6, 20260501, '2026-05-01 08:00:12', 37.5, 44.1, 1010.4, 0, 0.01500, 2, 298.70, 80.5),
(7, 20260501, '2026-05-01 08:01:00', 19.8, 71.2, 1014.7, 1, 0.00800, 1, 162.30, 97.0),
(8, 20260501, '2026-05-01 08:01:05', 20.1, 70.8, 1014.9, 1, 0.00800, 1, 164.10, 96.4),
(9, 20260501, '2026-05-01 08:01:10', 19.5, 72.0, 1015.1, 0, 0.00800, 2, 158.90, 98.2),
(10,20260501, '2026-05-01 08:01:15', 20.4, 69.5, 1014.6, 1, 0.00800, 1, 167.50, 95.8),
-- Round 2
(1, 20260501, '2026-05-01 09:00:00', 22.8, 64.9, 1013.0, 1, 0.01000, 1, 185.10, 92.1),
(2, 20260501, '2026-05-01 09:00:05', 22.2, 66.8, 1013.3, 1, 0.01000, 1, 179.50, 87.9),
(3, 20260501, '2026-05-01 09:00:10', 23.5, 63.2, 1012.7, 0, 0.01000, 2, 203.20, 94.7),
(4, 20260501, '2026-05-01 09:00:03', 40.1, 41.2, 1009.9, 1, 0.01500, 1, 315.80, 76.1),
(5, 20260501, '2026-05-01 09:00:08', 40.8, 39.8, 1009.5, 1, 0.01500, 1, 322.40, 73.5),
(6, 20260501, '2026-05-01 09:00:12', 38.9, 43.5, 1010.2, 0, 0.01500, 2, 302.10, 80.0),
(7, 20260501, '2026-05-01 09:01:00', 20.3, 70.5, 1014.5, 1, 0.00800, 1, 163.90, 96.6),
(8, 20260501, '2026-05-01 09:01:05', 20.6, 70.1, 1014.7, 1, 0.00800, 1, 165.40, 96.0),
(9, 20260501, '2026-05-01 09:01:10', 19.9, 71.6, 1014.9, 0, 0.00800, 2, 160.20, 97.8),
(10,20260501, '2026-05-01 09:01:15', 20.8, 69.0, 1014.4, 1, 0.00800, 1, 168.70, 95.3);
GO