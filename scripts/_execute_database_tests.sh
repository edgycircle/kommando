#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Wait for PostgreSQL
until pg_isready; do
  sleep 1
done

# Drop database if it exists
if psql "kommando_test" -c '\q' 2>&1; then
  dropdb "kommando_test"
fi

# Create database
createdb "kommando_test"

# Run migrations
psql "kommando_test" < ./db/migrations/1.up.sql

# Run tests
bin/rake database
