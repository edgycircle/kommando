#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

parallel --jobs 0 --no-notice --line-buffer --halt 'now,done=1' {1} ::: \
  'postgres -k $PGHOST' \
  './scripts/_execute_database_tests.sh' \
