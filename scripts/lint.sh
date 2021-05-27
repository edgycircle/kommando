#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

bin/rubocop \
  --force-exclusion \
  --auto-correct \
  --config .rubocop.yml \
  .
