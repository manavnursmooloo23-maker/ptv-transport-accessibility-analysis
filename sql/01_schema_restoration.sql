-- =========================================================
-- 1. SCHEMA INITIALIZATION
-- =========================================================
CREATE SCHEMA IF NOT EXISTS ptv;

-- =========================================================
-- 2. ABS DEMOGRAPHIC & ALLOCATION TABLES
-- =========================================================
CREATE TABLE ptv.mb_pop_2021 (
    mc_code BIGINT,
    mc_category TEXT,
    area_alb FLOAT,
    dwelling INTEGER,
    person INTEGER,
    state INTEGER
);

CREATE TABLE ptv.lga2021 (
    mb_code BIGINT,
    lga_code INTEGER,
    lga_name TEXT,
    state_code INTEGER,
    state_name TEXT,
    aus_code TEXT,
    aus_name TEXT,
    area_alb FLOAT,
    asgs_loci_uri TEXT
);

CREATE TABLE ptv.sal2021 (
    mb_code BIGINT,
    sal_code INTEGER,
    sal_name TEXT,
    state_code INTEGER,
    state_name TEXT,
    aus_code TEXT,
    aus_name TEXT,
    area_alb FLOAT,
    asgs_uri_url TEXT
);

-- =========================================================
-- 3. GTFS OPERATIONAL TRANSIT TABLES
-- =========================================================
CREATE TABLE ptv.agency (
    agency_id TEXT,
    agency_name TEXT,
    agency_url TEXT,
    agency_timezone TEXT,
    agency_lang TEXT,
    agency_fare_url TEXT
);

CREATE TABLE ptv.calendar (
    service_id TEXT,
    monday INTEGER,
    tuesday INTEGER,
    wednesday INTEGER,
    thursday INTEGER,
    friday INTEGER,
    saturday INTEGER,
    sunday INTEGER,
    start_date DATE,
    end_date DATE
);

CREATE TABLE ptv.calendar_dates (
    service_id TEXT,
    date DATE,
    exception_type INTEGER
);

CREATE TABLE ptv.levels (
    level_id TEXT,
    level_index INTEGER,
    level_name TEXT
);

CREATE TABLE ptv.pathways (
    pathway_id TEXT PRIMARY KEY,
    from_stop_id TEXT,
    to_stop_id TEXT,
    pathway_mode INTEGER,
    is_bidirectional INTEGER,
    traversal_time INTEGER
);

CREATE TABLE ptv.routes (
    route_id TEXT,
    agency_id TEXT,
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INTEGER,
    route_color TEXT,
    route_text_color TEXT
);

CREATE TABLE ptv.shapes (
    shape_id TEXT,
    shape_pt_lat FLOAT,
    shape_pt_lon FLOAT,
    shape_pt_sequence INT,
    shape_dist_traveled FLOAT
);

CREATE TABLE ptv.stop_times (
    trip_id TEXT,
    arrival_time TEXT,
    departure_time TEXT,
    stop_id TEXT,
    stop_sequence INT,
    stop_headsign TEXT,
    pickup_type INT,
    drop_off_type INT,
    shape_dist_traveled FLOAT
);

CREATE TABLE ptv.stops (
    stop_id TEXT,
    stop_name TEXT,
    stop_lat FLOAT,
    stop_lon FLOAT,
    location_type TEXT,
    parent_station TEXT,
    wheelchair_boarding INT,
    level_id TEXT,
    platform_code TEXT
);

CREATE TABLE ptv.transfers (
    from_stop_id TEXT,
    to_stop_id TEXT,
    from_route_id TEXT,
    to_route_id TEXT,
    from_trip_id TEXT,
    to_trip_id TEXT,
    transfer_type INT,
    min_transfer_time FLOAT
);

CREATE TABLE ptv.trips (
    route_id TEXT,
    service_id TEXT,
    trip_id TEXT,
    shape_id TEXT,
    trip_headsign TEXT,
    direction_id INT,
    block_id TEXT,
    wheelchair_accessible INT
);
