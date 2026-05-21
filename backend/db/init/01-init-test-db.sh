#!/bin/bash
set -e

# Create test database for running tests
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE cigrp_test;
    GRANT ALL PRIVILEGES ON DATABASE cigrp_test TO $POSTGRES_USER;
EOSQL

# Enable PostGIS extensions on both databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "cigrp" <<-'EOSQL'
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE SCHEMA IF NOT EXISTS ra_app;
    CREATE SCHEMA IF NOT EXISTS ra_vector;
    CREATE SCHEMA IF NOT EXISTS ra_raster;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "cigrp_test" <<-'EOSQL'
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE SCHEMA IF NOT EXISTS ra_app;
    CREATE SCHEMA IF NOT EXISTS ra_vector;
    CREATE SCHEMA IF NOT EXISTS ra_raster;
EOSQL

echo "Database initialization completed with PostGIS extensions"
