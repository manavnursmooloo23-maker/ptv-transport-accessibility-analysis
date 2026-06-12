#!/bin/bash
# =========================================================================
# Programmatic Mesh Block Shapefile Ingestion using ogr2ogr
# =========================================================================

ogr2ogr -f "PostgreSQL" \
  PG:"host=localhost port=5435 dbname=ptv-db user=postgres password=postgres" \
  ./extdata/mb2021.shp \
  -nln ptv.mb2021 \
  -nlt PROMOTE_TO_MULTI \
  -lco GEOMETRY_NAME=geom \
  -lco FID=id \
  -overwrite
