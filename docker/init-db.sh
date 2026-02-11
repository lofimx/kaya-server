#!/bin/bash
set -e

# Enable PostgreSQL extensions on the kaya_production database.
# This script runs once when the Postgres container is first initialized.

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
EOSQL
