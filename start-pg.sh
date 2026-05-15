#!/usr/bin/env bash
# Initialize (if missing) and start the locally-built Postgres cluster on
# a non-standard port. All binaries come from ./pg-install/.
set -euo pipefail
cd "$(dirname "$0")"

PG_PREFIX="$PWD/pg-install"
export PATH="$PG_PREFIX/bin:$PATH"
export PGDATA="$PWD/pgdata"
export PGPORT="${PGPORT:-55432}"

if [[ ! -x "$PG_PREFIX/bin/postgres" ]]; then
  echo "Postgres not built yet. Run ./build.sh first." >&2
  exit 1
fi

if [[ ! -d "$PGDATA" ]]; then
  initdb -D "$PGDATA" -U "$USER" --auth=trust --encoding=UTF8 --locale=C
fi

CONF="$PGDATA/postgresql.conf"
grep -q "^port = " "$CONF" || echo "port = $PGPORT" >> "$CONF"
# Default socket dir is /run/postgresql (system-owned); use /tmp for our
# user-owned cluster.
grep -q "^unix_socket_directories" "$CONF" || \
  echo "unix_socket_directories = '/tmp'" >> "$CONF"

pg_ctl -D "$PGDATA" -l "$PWD/pg.log" status >/dev/null 2>&1 || \
  pg_ctl -D "$PGDATA" -l "$PWD/pg.log" -w start

echo
echo "Postgres up on port $PGPORT. Connect with:"
echo "  $PG_PREFIX/bin/psql -h /tmp -p $PGPORT -U $USER postgres"
echo "Logs: $PWD/pg.log"
