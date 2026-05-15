#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$PWD/pg-install/bin:$PATH"
pg_ctl -D "$PWD/pgdata" -w stop -m fast
