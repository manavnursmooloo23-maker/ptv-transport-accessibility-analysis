# Public Transport Accessibility Analysis (Greater Melbourne)

## 🔍 Overview
This repository contains a full-stack spatial data engineering and analytics solution developed to evaluate public transport coverage against demographic distributions across the Greater Melbourne Metropolitan area. 

Acting as a Data Analyst for **Public Transport Victoria (PTV)**, this project integrates multi-million row General Transit Feed Specification (GTFS) data from the Mobility Database with geospatial boundary files and national census records from the Australian Bureau of Statistics (ABS). The ultimate goal was to identify critical transport blind spots and assess suburb-level infrastructure scaling.

---

## 🏗️ System Architecture & Data Pipeline

The pipeline was built inside an isolated, containerized environment using **Docker**, passing spatial and relational tables into a local **PostgreSQL / PostGIS** instance. 

```text
[GTFS Transit Data] ---> (DBeaver CSV Engine) --┐
[Census Data (XLSX)] --> (Data Conversion) -----┼--> [PostgreSQL / PostGIS] ---> [Staging Tables &] ---> [QGIS Analytical]
[ABS Meshblocks] ------> (ogr2ogr CLI Engine) --┘     (Containerized Docker)      (Spatial Indexes)        (High-Res Heatmaps)

```
  ---

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

---

## 📊 Deep-Dive Geospatial Analysis & Policy Insights

The final analytical output synthesized multi-million row GTFS spatial points with ABS meshblock demographic vectors to expose a stark structural contrast in Melbourne's urban framework.

### 1. Population Coverage Analysis
*This layer isolates the demographic dimension, calculating the percentage of the actual resident population living within a walkable 400-meter ($0.4\text{ km}$) transit catchment radius.*

  [High Density Urban Grid] ────────> 80% – 100% Core Population Coverage (Established Inner Core)
  [Linear Ribbon Corridors] ────────> High Pop Coverage / Restricted Spatial Footprint (Peninsula Axis)
  [Sparsely Settled Peri-Urban] ────> 0% – 20% Population Blindspots (Rural/Growth Fringes)

* **The Urban Core & Middle Ring Efficiency (80% – 100%):** A continuous, high-accessibility spatial block extends from inner northern hubs (Brunswick, Coburg) through the eastern commercial centers (Richmond, Hawthorn, Box Hill), cascading down the southeastern sandbelt (Brighton, Dandenong) to western industrial-residential nodes (Footscray, Sunshine). This reflects the legacy of a dense, overlapping multimodal grid where radial rail lines intersect with grid-based tram and bus networks.
* **Linear Coastal Density & Ribbon Development:** The eastern coast of Port Phillip Bay (Frankston down to Mount Martha) and the isolated tips of the Mornington Peninsula (Portsea, Sorrento) exhibit high population coverage despite their distance from the CBD. This is a classic signature of **ribbon development**: residential zoning is strictly confined along a primary highway corridor (Nepean Highway) and rail axis, meaning the localized population clusters tightly around the transit assets.
* **Systemic Fringe Blind Spots (0% – 20%):** Critical transit deficits are localized in three structural zones:
  * **The Far North Rural Interface:** Non-nucleated rural layouts across the Macedon Ranges, Mitchell Shire (north of Wallan), and the forested topography of Kinglake/Whittlesea.
  * **Topographic Barriers (East):** Scattered lifestyle properties in the rugged terrain of the Yarra Valley (Warburton) and Dandenong Ranges, where high slope gradients introduce severe geospatial friction for traditional transit routing.
  * **Infrastructure Lag in Western Growth Corridors:** Newly subdivided residential zones around Melton and Wyndham Vale where rapid property development has outpaced state infrastructure scaling, leaving major residential pockets unserved.

---

### 2. Area Coverage Analysis
*This layer isolates the geographic dimension, computing the exact surface area percentage of a suburb's total boundary covered by the 400-meter buffers ($ST\_Area$).*

* **Hyper-Nucleated Urban Grids (80% – 100%):** High area coverage is strictly locked into the central business district (CBD) grid and immediate inner-ring suburbs (Carlton, Fitzroy, Collingwood, South Melbourne). Here, transit stop frequencies are so dense that catchment zones overlap almost completely, leaving zero spatial gaps within the legal suburb boundaries.
* **Corridor Branching & Transit-Oriented Development (20% – 60%):** Symmetrical, branching bands of medium area coverage clearly trace Melbourne’s historical radial transit corridors. This spatial footprint expands cleanly along the South Eastern highway/rail axis toward Clayton/Springvale and the Eastern Freeway path toward Manningham and Whitehorse, highlighting traditional transit-oriented development patterns.
* **The "Green Wedge" Boundary Drop (0% – 20%):** Almost the entire outer periphery of Greater Melbourne drops into a spatial vacuum on this map. Even within major outer town centers like Sunbury, Healesville, or Flinders, the overall suburb area coverage fails to breach 20% due to the inclusion of massive, unserved agricultural zones, state forests, and protected parklands within their administrative boundaries.

---

### 💡 Strategic Urban Planning Takeaways (High Pop vs. Low Area)

By configuring this multi-dimensional spatial join, the database pipeline highlights a critical urban planning phenomenon unique to the Greater Melbourne Metropolitan area:

> **The Nucleated Center Paradox:** Outer ring and peri-urban suburbs frequently display excellent **Population Coverage (80%–100%)** alongside abysmal **Area Coverage (0%–20%)**. 
> 
> This indicates that while local councils are highly effective at clustering residential populations inside compact, walkable town centers or along single transit-serviced roads, the vast majority of the landmass consists of protected **"Green Wedge" zones** and farms. For data engineers and planners, this proves that evaluating transit access by raw suburb area alone introduces extreme bias; demographic weight must be spatially intersected to uncover the true operational efficiency of a public transit network.
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

[PTV Case Study](https://github.com/manavnursmooloo23-maker/portfolio-proj/blob/main/projects/ptv-analysis.md)

```

```
