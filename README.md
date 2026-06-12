# Public Transport Accessibility Analysis (Greater Melbourne)
🚀 **Enterprise Spatial Data Engineering & Analytics Case Study**

## 🔍 Overview
This repository contains a full-stack spatial data engineering and analytics solution developed to evaluate public transport coverage against demographic distributions across the Greater Melbourne Metropolitan area. 

Acting as a Data Analyst for **Public Transport Victoria (PTV)**, this project integrates multi-million row General Transit Feed Specification (GTFS) data from the Mobility Database with geospatial boundary files and national census records from the Australian Bureau of Statistics (ABS). The ultimate goal was to identify critical transport blind spots and assess suburb-level infrastructure scaling.

---

## 🏗️ System Architecture & Data Pipeline

The pipeline was built inside an isolated, containerized environment using **Docker**, passing spatial and relational tables into a local **PostgreSQL / PostGIS** instance. 

  [GTFS Transit Data] ---> (DBeaver CSV Engine) --┐
  [Census Data (XLSX)] --> (Data Conversion) -----┼--> [PostgreSQL / PostGIS] ---> [Staging Tables &] ---> [QGIS Analytical]
  [ABS Meshblocks] ------> (ogr2ogr CLI Engine) --┘     (Containerized Docker)      (Spatial Indexes)        (High-Res Heatmaps)

### 1. Data Restoration & Ingestion Mechanics

* **Spatial Ingestion Engine:** Rather than relying on simple GUI loaders, the project utilized the `ogr2ogr` command-line utility via GDAL to map, multi-polygon promote (`PROMOTE_TO_MULTI`), and programmatically inject complex ESRI Shapefile geometries (`mb2021.shp`) with clean database identifiers directly into the target database schema.
* **Relational Storage:** Relational datasets containing transport frequencies and census distributions were normalized, schema-typed, and bulk-loaded via native database stream copy utilities inside `DBeaver`.

---

## ⚡ Technical Challenges & Performance Engineering

When handling datasets at scale (such as the `ptv.shapes` table containing **over 10.4 million rows** or `ptv.stop_times` tracking **8.2 million transit events**), writing technically correct queries is not enough. Without proper optimization, standard analytical spatial joins across these structures would saturate system memory and require hours to resolve.

To build a production-grade environment, the following engineering choices were implemented:

### 1. Relational & Spatial Index Optimization

To support intensive table joins downstream, selective **B-Tree indexes** were structured on critical primary/foreign key join paths (`trip_id`, `service_id`, and `route_id`). For geometric computing, **GIST (Generalized Search Tree) Spatial Indexes** were placed over geographic column layers to leverage bounding-box spatial filtering.

```sql
-- Performance Tuning Indexes
CREATE INDEX IF NOT EXISTS idx_stop_times_trip ON ptv.stop_times(trip_id);
CREATE INDEX IF NOT EXISTS idx_trips_service ON ptv.trips(service_id);
CREATE INDEX IF NOT EXISTS idx_trips_route ON ptv.trips(route_id);

CREATE INDEX IF NOT EXISTS idx_mb_geom ON ptv.mb2021_full USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_stops_geom ON ptv.stops_geom USING GIST (geom);

```

### 2. Multi-Stage Query Design (Staging Strategy)

Instead of executing resource-heavy monolithic queries, the calculation architecture was broken up into **13 isolated, sequential staging steps**.

* **The JIT (Just-In-Time) Optimizer Bypass:** PostGIS buffer generation on complex geometries can cause the standard Postgres JIT compiler to over-optimize, wasting massive processing cycles. JIT compilation was explicitly deactivated (`SET jit = off;`) prior to heavy spatial modifications to cut query execution latency.
* **Spatial Join Refinement (`&&` Operator):** When running intersections between residential blocks and 400-meter transit catchment radii (`ST_Intersects`), the index-backed **Bounding Box overlap operator (`&&`)** was evaluated *first* to drop thousands of non-proximal records prior to executing the accurate, computationally expensive geometric calculation.

```sql
-- Example from Staging Step 4: Finding Covered Mesh Blocks
CREATE TABLE ptv.mb_covered AS
SELECT DISTINCT
    mb.MB_CODE21,
    sb.stop_id
FROM ptv.mb_melbourne mb
JOIN ptv.stop_buffers sb
  ON mb.geom && sb.buffer_geom               -- 1st Pass: Fast bounding-box filter
 AND ST_Intersects(mb.geom, sb.buffer_geom); -- 2nd Pass: Precision geometry intersect

```

### 3. Route Signature De-duplication

A major data explosion risk occurred when mapping route types (Tram `0`, Train `2`, Bus `3`). In real-world GTFS tracking, one `route_id` may yield dozens of duplicate short-names. To preserve analytical integrity and satisfy specific transit criteria (e.g., Weekday-only operations), conditional aggregation profiles were built to explicitly count the combination of uniquely matched route names and code signatures per suburb.

```sql
COUNT(DISTINCT CASE WHEN mr.vehicle_type = 'Bus' THEN (mr.route_short_name, mr.route_long_name) END)

```

---

## 📊 Analytical Insights & Spatial Visualizations

The output of the final processing matrix generated a clean, 577-row summary table aggregating **Population Coverage (%)**, **Total Area Coverage (%)**, and **Weekday Route Availability** across every suburb in Greater Melbourne.

### 1. Population Coverage Heatmap

*Measures the percentage of residents living within a walkable 400-meter public transport buffer.*

* **Inner Core Efficiency (80–100%):** Melbourne’s established middle and inner core (e.g., Brunswick, Richmond, Box Hill, Footscray) exhibits high public transport access density, benefiting from a robust overlapping grid of historical tram, train, and bus lines.
* **Linear Coastal Density:** Isolated outer pockets like the tip of the Mornington Peninsula (Portsea/Sorrento) display high population coverage because suburban zoning tightly hugs a single main highway axis that is fully serviced by regional transit routes.

### 2. Area Coverage Heatmap

*Measures the raw geographic boundary area covered by the 400-meter transport buffers.*

* **The Urban Dilemma (High Pop Coverage vs. Low Area Coverage):** Comparing these two heatmaps reveals a key urban planning insight. While outer fringe growth corridors often show decent population coverage (as residents live clustered closely around established town hubs), their **Area Coverage registers below 20% (White)**. This visually demonstrates the spatial signature of Melbourne’s strictly protected, unserved **"Green Wedge" zones**, farms, and parklands.

---

## 🛠️ Tools, Core Functions & Technologies

* **Database Engine:** PostgreSQL (w/ PostGIS Spatial Extensions) Hosted via Docker
* **Spatial Import Engine:** GDAL `ogr2ogr` (CLI)
* **GIS Mapping Suite:** QGIS (Desktop 3.x)
* **Key PostGIS Methods Utilized:**
* `ST_Buffer(geom::geography, 400)::geometry` — Generates exact metric-distance walkable buffers.
* `ST_Union(geom)` — Dissolves boundaries to create seamless suburb-level shapes.
* `ST_Intersection(geom, geom)` — Extracts precise spatial overlaps between buffers and suburbs.
* `ST_Area(geom::geography)` — Computes accurate surface area metrics in square meters.



---

## 🔗 Links

* **Portfolio Case Study:** [PTV Access Analysis](https://github.com/manavnursmooloo23-maker/portfolio-proj/blob/main/projects/ptv-analysis.md)

```

```
