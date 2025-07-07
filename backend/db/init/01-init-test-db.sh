#!/bin/bash
set -e

# Create test database for running tests
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE cigrp_test;
    GRANT ALL PRIVILEGES ON DATABASE cigrp_test TO $POSTGRES_USER;
EOSQL

# Enable PostGIS extensions on both databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "cigrp" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "cigrp_test" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOSQL

echo "Database initialization completed with PostGIS extensions"
