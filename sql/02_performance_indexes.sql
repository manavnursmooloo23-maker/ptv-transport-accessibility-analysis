-- =========================================================================
-- Relational & Spatial Index Optimization
-- Target: Mitigate latency on million-row table connections (stop_times, shapes)
-- =========================================================================

-- B-Tree Indexes for Relational Join Predicates
CREATE INDEX IF NOT EXISTS idx_stop_times_trip ON ptv.stop_times(trip_id);
CREATE INDEX IF NOT EXISTS idx_trips_service ON ptv.trips(service_id);
CREATE INDEX IF NOT EXISTS idx_trips_route ON ptv.trips(route_id);

-- GIST (Generalized Search Tree) Indexes for Geographic Layer Buffers
CREATE INDEX IF NOT EXISTS idx_mb_geom ON ptv.mb2021_full USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_stops_geom ON ptv.stops_geom USING GIST (geom);
