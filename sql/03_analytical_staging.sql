-- =========================================================
-- Task 2: Data Analysis for Melbourne Metropolitan Area
-- Pipeline Staging Methodology
-- =========================================================

-- Step 1: Filter Geographies to Greater Melbourne Framework
DROP TABLE IF EXISTS ptv.mb_melbourne;
CREATE TABLE ptv.mb_melbourne AS
SELECT *
FROM ptv.mb2021_full
WHERE gcc_name21 = 'Greater Melbourne'
  AND MB_CODE21 ~ '^[0-9]+$';

-- Step 2: Establish Explicit Mesh Block to Suburb (SAL) Mapping
DROP TABLE IF EXISTS ptv.mb_suburb;
CREATE TABLE ptv.mb_suburb AS
SELECT 
    mb.MB_CODE21,
    sal.sal_code AS suburb_code,
    sal.sal_name AS suburb_name
FROM ptv.mb_melbourne mb
JOIN ptv.sal2021 sal ON mb.MB_CODE21::bigint = sal.mb_code
WHERE sal.state_code = 2;

-- Step 3: Construct 400m Buffer Zones Over Spatial Stop Coordinates
DROP TABLE IF EXISTS ptv.stop_buffers;

-- Disable JIT compilation to avoid over-optimization of spatial extensions
SET jit = off;

CREATE TABLE ptv.stop_buffers AS
SELECT 
    stop_id,
    ST_Buffer(geom::geography, 400)::geometry AS buffer_geom
FROM ptv.stops_geom;

CREATE INDEX IF NOT EXISTS idx_stop_buffers_geom ON ptv.stop_buffers USING GIST (buffer_geom);

-- Step 4: Map Overlapping Structural Buffers to Intersected Mesh Blocks
DROP TABLE IF EXISTS ptv.mb_covered;
CREATE TABLE ptv.mb_covered AS
SELECT DISTINCT
    mb.MB_CODE21,
    sb.stop_id
FROM ptv.mb_melbourne mb
JOIN ptv.stop_buffers sb
  ON mb.geom && sb.buffer_geom               -- Index-backed Bounding Box pass filter
 AND ST_Intersects(mb.geom, sb.buffer_geom); -- Exact geometry intersection validation

-- Step 5: Extract Weekday-Only GTFS Route Sequences and Classify Vehicle Matrix
DROP TABLE IF EXISTS ptv.routes_per_stop;
CREATE TABLE ptv.routes_per_stop AS
SELECT DISTINCT
    st.stop_id,
    r.route_short_name,
    r.route_long_name,
    CASE 
        WHEN r.route_type = 0 THEN 'Tram'
        WHEN r.route_type = 2 THEN 'Train'
        WHEN r.route_type = 3 THEN 'Bus'
        ELSE 'Unknown'
    END AS vehicle_type
FROM ptv.stop_times st
JOIN ptv.trips t ON st.trip_id = t.trip_id
JOIN ptv.routes r ON t.route_id = r.route_id
JOIN ptv.calendar c ON t.service_id = c.service_id
WHERE r.route_type IN (0,2,3)
  AND (c.monday = 1 OR c.tuesday = 1 OR c.wednesday = 1 OR c.thursday = 1 OR c.friday = 1);

-- Step 6: Map Distinct Accessible Route Signatures to Specific Mesh Blocks
DROP TABLE IF EXISTS ptv.mb_routes;
CREATE TABLE ptv.mb_routes AS
SELECT DISTINCT
    mc.MB_CODE21,
    r.route_short_name,
    r.route_long_name,
    r.vehicle_type
FROM ptv.mb_covered mc
JOIN ptv.routes_per_stop r ON mc.stop_id = r.stop_id;

-- Step 7: Aggregate Unique Weekday Bus Routes to Suburb Levels
DROP TABLE IF EXISTS ptv.suburb_bus_routes;
CREATE TABLE ptv.suburb_bus_routes AS
SELECT 
    ms.suburb_code,
    COUNT(DISTINCT CASE 
        WHEN mr.vehicle_type = 'Bus' 
        THEN (mr.route_short_name, mr.route_long_name) 
    END) AS weekday_bus_routes
FROM ptv.mb_suburb ms
LEFT JOIN ptv.mb_routes mr ON ms.MB_CODE21 = mr.MB_CODE21
GROUP BY ms.suburb_code;

-- Step 8: Compute Baseline Suburb Population Totals from Mesh Block Census Data
DROP TABLE IF EXISTS ptv.suburb_population;
CREATE TABLE ptv.suburb_population AS
SELECT 
    ms.suburb_code,
    MAX(ms.suburb_name) AS suburb_name,
    SUM(pop.person) AS suburb_population
FROM ptv.mb_suburb ms
JOIN ptv.mb_pop_2021 pop ON ms.MB_CODE21::bigint = pop.mc_code
GROUP BY ms.suburb_code;

-- Step 9: Quantify Aggregated Census Population Intersecting Transport Catchments
DROP TABLE IF EXISTS ptv.suburb_covered_population;
CREATE TABLE ptv.suburb_covered_population AS
SELECT 
    suburb_code,
    SUM(person) AS covered_population
FROM (
    SELECT DISTINCT
        ms.MB_CODE21,
        ms.suburb_code,
        pop.person
    FROM ptv.mb_suburb ms
    JOIN ptv.mb_covered mc ON ms.MB_CODE21 = mc.MB_CODE21
    JOIN ptv.mb_pop_2021 pop ON ms.MB_CODE21::bigint = pop.mc_code
) t
GROUP BY suburb_code;

-- Step 10: Calculate Proportional Population Coverage Percentages
DROP TABLE IF EXISTS ptv.suburb_pop_coverage;
CREATE TABLE ptv.suburb_pop_coverage AS
SELECT 
    sp.suburb_code,
    sp.suburb_population,
    COALESCE(scp.covered_population, 0) AS covered_population,
    CASE 
        WHEN sp.suburb_population = 0 THEN 0
        ELSE (COALESCE(scp.covered_population, 0) * 100.0 / sp.suburb_population)
    END AS pop_covered
FROM ptv.suburb_population sp
LEFT JOIN ptv.suburb_covered_population scp ON sp.suburb_code = scp.suburb_code;

-- Step 11: Dissolve Mesh Block Geometries to Standard Suburb Boundaries
DROP TABLE IF EXISTS ptv.suburb_geom;
CREATE TABLE ptv.suburb_geom AS
SELECT 
    ms.suburb_code,
    MAX(ms.suburb_name) AS suburb_name,
    ST_Union(mb.geom) AS geom
FROM ptv.mb_suburb ms
JOIN ptv.mb_melbourne mb ON ms.MB_CODE21 = mb.MB_CODE21
GROUP BY ms.suburb_code;

-- Step 12: Calculate True Surface Area Intersection Coverage Metrics (%)
DROP TABLE IF EXISTS ptv.suburb_area_coverage;
CREATE TABLE ptv.suburb_area_coverage AS
SELECT 
    sg.suburb_code,
    (
        ST_Area(ST_Intersection(MAX(sg.geom)::geometry, ST_Union(sb.buffer_geom))::geography)
        / ST_Area(MAX(sg.geom)::geography)
    ) * 100 AS area_covered
FROM ptv.suburb_geom sg
JOIN ptv.stop_buffers sb ON sg.geom && sb.buffer_geom
GROUP BY sg.suburb_code;

-- Step 13: Synthesize Consolidated Analytical Matrix (Expected final target output)
DROP TABLE IF EXISTS ptv.final_suburb_table;
CREATE TABLE ptv.final_suburb_table AS
SELECT 
    spc.suburb_code,
    sg.suburb_name,
    spc.suburb_population,
    spc.pop_covered,
    COALESCE(sbr.weekday_bus_routes, 0) AS weekday_bus_routes,
    COALESCE(sac.area_covered, 0) AS area_covered,
    sg.geom
FROM ptv.suburb_pop_coverage spc
LEFT JOIN ptv.suburb_bus_routes sbr ON spc.suburb_code = sbr.suburb_code
LEFT JOIN ptv.suburb_area_coverage sac ON spc.suburb_code = sac.suburb_code
JOIN ptv.suburb_geom sg ON spc.suburb_code = sg.suburb_code;

-- Step 14: Target Frame Verification Assertion Check (Target: 577 Rows)
SELECT COUNT(*) FROM ptv.final_suburb_table;
