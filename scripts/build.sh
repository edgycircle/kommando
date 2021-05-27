#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

scripts/lint.sh
scripts/isolation-test-runner.sh
scripts/database-test-runner.sh
