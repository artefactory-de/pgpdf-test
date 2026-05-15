#!/usr/bin/env bash
# Build Postgres from source into ./pg-install/. Idempotent — skips if a
# usable postgres binary already lives there.
#
# Slim configure: no ICU, no OpenSSL, no LLVM. Keeps readline + zlib so psql
# stays usable and dumps stay compressed. Adjust if you need more.
set -euo pipefail
cd "$(dirname "$0")"

PG_VERSION="${PG_VERSION:-18.3}"
PG_SHA256="${PG_SHA256:-d95663fbbf3a80f81a9d98d895266bdcb74ba274bcc04ef6d76630a72dee016f}"
PREFIX="$PWD/pg-install"
BUILD_DIR="$PWD/pg-build"
TARBALL="postgresql-${PG_VERSION}.tar.bz2"

if [[ -x "$PREFIX/bin/postgres" ]]; then
  installed_ver=$("$PREFIX/bin/postgres" --version | awk '{print $NF}')
  if [[ "$installed_ver" == "$PG_VERSION" ]]; then
    echo "Postgres $PG_VERSION already built in $PREFIX (skipping)."
    exit 0
  fi
  echo "Found stale install ($installed_ver), rebuilding $PG_VERSION..."
  rm -rf "$PREFIX"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [[ ! -f "$TARBALL" ]]; then
  curl -fL -o "$TARBALL" \
    "https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${TARBALL}"
fi

echo "$PG_SHA256  $TARBALL" | sha256sum -c -

rm -rf "postgresql-${PG_VERSION}"
tar -xjf "$TARBALL"
cd "postgresql-${PG_VERSION}"

./configure \
  --prefix="$PREFIX" \
  --without-icu \
  --without-openssl \
  --without-llvm

make -j"$(nproc)" world-bin
make install-world-bin

echo
echo "Built Postgres $PG_VERSION into $PREFIX:"
"$PREFIX/bin/postgres" --version
"$PREFIX/bin/pg_config" --pgxs
