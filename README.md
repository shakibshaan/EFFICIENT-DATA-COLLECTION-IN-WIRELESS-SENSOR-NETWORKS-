# WSN Analytics — ε-Kernel Data Collection & SQL Warehouse

> **Efficient data collection in Wireless Sensor Networks with end-to-end analytics integration**, based on Cheng et al. (2016), *IEEE Transactions on Knowledge and Data Engineering*.

This project implements a full analytics pipeline for a Wireless Sensor Network (WSN): from geometric ε-kernel node selection that cuts energy waste by up to 55%, through a star-schema SQL Server data warehouse, to five production-ready T-SQL analytics queries covering energy auditing, environmental monitoring, quality control, battery forecasting, and zone-level KPI dashboarding.

---

## Table of Contents

- [Background](#background)
- [What This Project Does](#what-this-project-does)
- [Repository Structure](#repository-structure)
- [Database Schema](#database-schema)
  - [Dimension Tables](#dimension-tables)
  - [Fact Table](#fact-table)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Setup — Step by Step](#setup--step-by-step)
- [Sample Data](#sample-data)
- [Analytics Queries](#analytics-queries)
  - [Query 1 — Energy Consumption Audit](#query-1--energy-consumption-audit-by-zone-and-day)
  - [Query 2 — Hourly Time-Series with Rolling Average](#query-2--hourly-time-series-with-3-hour-rolling-average)
  - [Query 3 — ε-Approximation Quality Monitoring](#query-3--ε-approximation-quality-monitoring)
  - [Query 4 — Battery Health & Survivability Forecast](#query-4--battery-health--survivability-forecast)
  - [Query 5 — Zone-Level Kernel Efficiency Dashboard](#query-5--zone-level-kernel-efficiency-dashboard)
- [Key Concepts](#key-concepts)
  - [The ε-Kernel Algorithm](#the-ε-kernel-algorithm)
  - [Energy Model](#energy-model)
  - [Star Schema Design](#star-schema-design)
- [Sample Results](#sample-results)
- [Report Document](#report-document)
- [References](#references)

---

## Background

Wireless Sensor Networks deploy hundreds or thousands of battery-powered nodes that continuously sample environmental data — temperature, humidity, pressure — and relay it to a base station. The core challenge: **radio transmission is the dominant energy cost**, consuming roughly as much power per bit as thousands of CPU instructions. Naively forwarding every reading from every node drains batteries fast and limits network lifetime.

Cheng et al. (2016) solve this with **ε-kernel selection** — a computational geometry technique that identifies the smallest subset of nodes whose readings still represent the full network within a mathematically guaranteed error bound ε. Only those kernel nodes transmit, reducing energy consumption by 35–55% while preserving the analytical value of the data.

This project bridges that WSN protocol with a complete SQL analytics stack, demonstrating that the ε-kernel output is directly ingestible into a relational warehouse and queryable with standard T-SQL.

---

## What This Project Does

- **Star-schema warehouse** designed for WSN kernel readings, with dimension tables for zones, nodes, and calendar dates
- **Sample dataset** — 10 sensor nodes across 3 deployment zones, 20 kernel readings over 2 sensing rounds
- **5 analytics queries** covering the full operational lifecycle of a WSN deployment
- **Written report** (`WSN_Analytics_Report_Final.docx`) — a full academic paper with methodology, results, and discussion, formatted in 2-column layout with all SQL embedded

---

## Repository Structure

```
wsn-analytics/
│
├── sql/
│   ├── WSN_database_setup.sql      # Database creation, schema, and sample data
│   └── WSN_analytics.sql           # All 5 analytics queries
│
├── docs/
│   └── WSN_Analytics_Report_Final.docx   # Full academic report (2-column format)
│
└── README.md
```

---

## Database Schema

The warehouse follows a **star schema** — a single central fact table joined to lightweight dimension tables. This pattern minimises redundancy across millions of sensor readings while enabling fast GROUP BY aggregations on zone, date, and node attributes.

### Dimension Tables

#### `dim_DeploymentZone`
Geographic deployment areas. Each zone has a type (Environmental, Industrial, Smart City) which drives different alert thresholds and analytics filters.

| Column | Type | Description |
|---|---|---|
| ZoneID | INT IDENTITY PK | Surrogate key |
| ZoneName | VARCHAR(80) | Human-readable name, e.g. "Forest Sector A" |
| ZoneType | VARCHAR(30) | Category: Environmental / Industrial / Smart City |

#### `dim_SensorNode`
Registry of every physical node in the network. The `IsKernelCapable` flag records whether the ε-kernel algorithm has designated this node as a candidate for kernel selection.

| Column | Type | Description |
|---|---|---|
| NodeID | INT IDENTITY PK | Surrogate key |
| NodeCode | VARCHAR(20) UNIQUE | Hardware identifier, e.g. "NODE-007" |
| ZoneID | INT FK | Link to deployment zone |
| Latitude / Longitude | DECIMAL(9,6) | GPS coordinates |
| BatteryCapacityMAh | INT | Total battery capacity in milliamp-hours |
| IsKernelCapable | BIT | 1 = eligible for kernel selection |

#### `dim_Date`
Pre-populated calendar dimension (YYYYMMDD integer key). Enables efficient GROUP BY on year, month, and week without calling DATEPART in every query.

| Column | Type | Description |
|---|---|---|
| DateKey | INT PK | YYYYMMDD integer, e.g. 20260501 |
| FullDate | DATE UNIQUE | Calendar date |
| Year / Month / MonthName | SMALLINT / TINYINT / VARCHAR | Calendar attributes |

### Fact Table

#### `fact_KernelReading`
One row per kernel reading transmitted to the base station. The `EpsilonBound` column is the critical link between the WSN protocol and the analytics layer — it travels with every record so downstream queries can apply quality gates.

| Column | Type | Description |
|---|---|---|
| ReadingID | BIGINT IDENTITY PK | Surrogate key |
| NodeID | INT FK | Sensor node |
| DateKey | INT FK | Calendar date |
| ReadingTime | DATETIME2(3) | Precise timestamp |
| TemperatureC | DECIMAL(6,2) | Sensed temperature |
| HumidityPct | DECIMAL(5,2) | Relative humidity |
| PressureHPa | DECIMAL(7,2) | Atmospheric pressure |
| IsKernelNode | BIT | 1 = this node was selected as kernel node for this round |
| **EpsilonBound** | DECIMAL(7,5) | **ε quality parameter — approximation guarantee for this reading** |
| HopCount | TINYINT | Number of relay hops to base station |
| EnergyConsumedNJ | DECIMAL(10,4) | Energy used for this transmission in nanojoules |
| BatteryLevelPct | DECIMAL(5,2) | Remaining battery at time of reading |

---

## Getting Started

### Prerequisites

- **Microsoft SQL Server 2019+** (any edition including Developer/Express)
- **SQL Server Management Studio (SSMS)** or **Azure Data Studio**
- No external libraries or packages required — pure T-SQL

### Setup — Step by Step

**1. Clone the repository**

```bash
git clone https://github.com/your-username/wsn-analytics.git
cd wsn-analytics
```

**2. Run the database setup script**

Open `sql/WSN_database_setup.sql` in SSMS and execute it against your SQL Server instance. This script:
- Creates the `WSN_Analytics` database
- Creates all dimension tables (`dim_DeploymentZone`, `dim_SensorNode`, `dim_Date`)
- Creates the fact table (`fact_KernelReading`)
- Inserts 3 deployment zones, 10 sensor nodes, 2 date records, and 20 fact rows

```sql
-- Run in SSMS (the script handles USE master / USE WSN_Analytics automatically)
-- File: sql/WSN_database_setup.sql
```

> **Note:** The script uses `TRUNCATE TABLE fact_KernelReading` before inserting fact rows to allow safe re-runs. Run it as many times as needed — it is fully idempotent after the first run once the database exists. If re-running from scratch, drop the database first or comment out the `CREATE DATABASE` line.

**3. Run the analytics queries**

Open `sql/WSN_analytics.sql` in SSMS. The script opens with `USE WSN_Analytics; GO` so it targets the correct database automatically. You can run all five queries together or execute each one individually by selecting the block and pressing F5.

---

## Sample Data

The setup script seeds a representative deployment with:

**3 Deployment Zones**

| Zone | Type | Location |
|---|---|---|
| Forest Sector A | Environmental | San Francisco Bay Area (~37.68°N) |
| Industrial Plant B | Industrial | San Francisco Bay Area (~37.70°N) |
| Urban Campus C | Smart City | San Jose area (~37.34°N) |

**10 Sensor Nodes** — 3 in Forest, 3 in Industrial, 4 in Urban. Nodes ending in odd numbers are kernel-capable; NODE-003, -006, and -009 are non-kernel nodes included to test the `IsKernelNode = 0` path.

**20 Fact Rows** — 2 sensing rounds (08:00 and 09:00 on 2026-05-01), all 10 nodes per round. Industrial Plant B nodes run noticeably hotter (38–41°C) and consume more energy (298–322 nJ/reading) than forest and urban nodes.

---

## Analytics Queries

All queries are in `sql/WSN_analytics.sql`. Each is self-contained and can be run independently.

### Query 1 — Energy Consumption Audit by Zone and Day

Quantifies total and average energy consumed by kernel nodes per zone per day, and calculates the estimated energy saving percentage (non-kernel nodes silenced). A declining `AvgEnergyPerReading_NJ` trend over time is the primary signal that the ε-kernel algorithm is converging and reducing kernel set size.

**Key output columns:** `TotalEnergy_NJ`, `AvgEnergyPerReading_NJ`, `KernelNodeReadings`, `EstimatedEnergySavingPct`

**Use case:** Daily operational energy report; input for battery replacement scheduling.

---

### Query 2 — Hourly Time-Series with 3-Hour Rolling Average

Computes per-zone hourly average temperature and humidity, then overlays a 3-hour backward-looking rolling mean using a T-SQL window function (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`). The rolling average smooths transient spikes and exposes underlying thermal trends.

**Key output columns:** `HourlyAvgTemp_C`, `HourlyAvgHumidity_Pct`, `RollingAvg3H_C`

**Use case:** Predictive maintenance; environmental compliance reporting; HVAC efficiency monitoring.

---

### Query 3 — ε-Approximation Quality Monitoring

Tracks the distribution of the `EpsilonBound` column across nodes, computing average, min, max, and 95th-percentile ε values, plus a violation count for readings that exceed a hardcoded threshold of 0.0200. Uses a two-CTE pattern (`grouped_data` + `percentiles`) to keep the `PERCENTILE_CONT` window function separate from the GROUP BY aggregation.

**Key output columns:** `AvgEpsilon`, `MaxEpsilon`, `P95_Epsilon`, `ViolationCount`, `ViolationPct`

**Use case:** Data quality assurance; alerting when approximation error exceeds acceptable bounds (recommended alert threshold: `ViolationPct > 5%`).

---

### Query 4 — Battery Health & Survivability Forecast

Uses two CTEs — `LatestBattery` (ROW_NUMBER to get the most recent reading per node) and `NodeAvgEnergy` (average energy per round) — to estimate how many additional sensing rounds each node can sustain before battery depletion. Applies the conversion factor `1 mAh at 3.3V ≈ 11,880,000 nJ`.

**Key output columns:** `CurrentBattery_Pct`, `AvgEnergyPerRound_NJ`, `EstimatedRoundsLeft`, `BatteryStatus` (OK / WARNING / CRITICAL)

**Use case:** Proactive maintenance scheduling; kernel re-assignment before a node fails and creates a coverage gap.

---

### Query 5 — Zone-Level Kernel Efficiency Dashboard

Executive-level summary combining three KPIs into a single `NetworkHealthScore` per zone (0–100 scale): battery level (40% weight), approximation accuracy (30% weight), and kernel efficiency ratio (30% weight). The kernel efficiency ratio (KER) is the proportion of readings that came from kernel-designated nodes — higher is better.

**Key output columns:** `KernelEfficiencyRatio_Pct`, `TotalEnergy_uJ`, `AvgApproxQuality`, `NetworkHealthScore`

**Use case:** Management dashboard; zone-level health monitoring; prioritising where to send field engineers.

---

## Key Concepts

### The ε-Kernel Algorithm

Given a set of n sensor nodes S = {s₁, s₂, ..., sₙ}, the ε-kernel K ⊆ S satisfies:

```
width(K, u) ≥ (1 − ε) · width(S, u)   for all unit vectors u ∈ Rᵈ
```

In plain terms: for every possible "direction" of measurement, the kernel subset spans at least (1 − ε) of the full dataset's range. Only kernel nodes transmit to the base station; all others go silent for that round.

The kernel size is bounded by **O(1/ε^((d−1)/2))**, which is independent of the total node count n — a crucial scalability property. Smaller ε = more accurate but larger kernel set and higher energy cost. Larger ε = smaller kernel, lower energy, coarser approximation.

**Centralized variant:** All nodes transmit once; base station selects the kernel for future rounds. Best for initial deployment.

**Distributed variant:** Nodes compute local kernels and merge them up a routing hierarchy. Avoids the expensive initial full broadcast; achieves 30–50% lower per-node energy consumption in typical configurations.

### Energy Model

The first-order radio model used throughout:

```
E_tx(k, d) = E_elec × k  +  E_amp × k × d²
E_rx(k)    = E_elec × k
```

Where `E_elec = 50 nJ/bit` (radio electronics) and `E_amp = 100 pJ/bit/m²` (power amplifier). The `EnergyConsumedNJ` column in `fact_KernelReading` stores the result of this calculation for each transmission, enabling the warehouse to track real energy expenditure over time.

### Star Schema Design

The warehouse uses the Kimball dimensional modelling pattern:

```
dim_DeploymentZone ──┐
dim_SensorNode     ──┼── fact_KernelReading
dim_Date           ──┘
```

This structure means analytics queries only need simple `JOIN` + `GROUP BY` operations — no recursive CTEs or nested subqueries needed for the most common aggregations. The `EpsilonBound` column in the fact table is deliberately kept at the finest grain (per-reading) so quality-aware downstream consumers can apply their own threshold logic.

---

## Sample Results

**Energy audit (Query 1) — 2026-05-01**

| Zone | TotalReadings | TotalEnergy_NJ | EnergySaving% |
|---|---|---|---|
| Forest Sector A | 6 | 1,047.40 | 33.33 |
| Industrial Plant B | 6 | 1,748.90 | 33.33 |
| Urban Campus C | 8 | 1,248.90 | 25.00 |

**Zone health dashboard (Query 5)**

| Zone | KernelEff% | AvgEpsilon | NetworkHealthScore |
|---|---|---|---|
| Urban Campus C | 75.0 | 0.00800 | 88.4 |
| Forest Sector A | 66.7 | 0.01000 | 85.9 |
| Industrial Plant B | 66.7 | 0.01500 | 82.3 |

Urban Campus C leads on health score due to its lower ε values and higher kernel efficiency ratio. Industrial Plant B scores lowest because of its elevated ε (higher approximation error from heavy-load industrial conditions) despite having the largest battery reserves.

---

## Report Document

`docs/WSN_Analytics_Report_Final.docx` is a full academic paper covering:

- Abstract and introduction
- Literature review — LEACH, Compressive Sensing, and positioning of Cheng et al.
- Methodology — ε-kernel formulation, energy model, centralized vs. distributed variants
- Data analytics section — complete schema DDL, all 5 queries with result tables
- Results and discussion — energy reduction figures, analytics performance benchmarks, tradeoffs
- Reflection and conclusion
- Full references

The document is formatted in 2-column academic layout with code blocks, styled data tables, and running headers/footers.

---

## References

- Cheng, S., Li, J., Ren, Q., & Yu, L. (2016). Bernoulli sampling based (ε, δ)-approximate aggregation in large-scale sensor networks. *IEEE Transactions on Knowledge and Data Engineering*, 28(5). https://doi.org/10.1109/TKDE.2015.2449307
- Heinzelman, W. R., Chandrakasan, A., & Balakrishnan, H. (2000). Energy-efficient communication protocol for wireless microsensor networks. *Proc. 33rd HICSS*. IEEE.
- Akyildiz, I. F., et al. (2002). Wireless sensor networks: a survey. *Computer Networks*, 38(4), 393–422.
- Donoho, D. L. (2006). Compressed sensing. *IEEE Transactions on Information Theory*, 52(4), 1289–1306.
- Kimball, R., & Ross, M. (2013). *The Data Warehouse Toolkit* (3rd ed.). Wiley.

---

*Platform: Microsoft SQL Server 2019+ · T-SQL · Star Schema Dimensional Modelling*
