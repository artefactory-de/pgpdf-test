#!/usr/bin/env bash
# Build the locally-vendored Postgres (./pg-install/) then build + install
# the pgpdf extension into it. Everything stays under the project directory.
set -euo pipefail
cd "$(dirname "$0")"

./build-pg.sh

export PATH="$PWD/pg-install/bin:$PATH"

git submodule update --init --recursive

cd pgpdf
# Skip LLVM bitcode (we built PG without LLVM anyway).
make clean >/dev/null 2>&1 || true
make with_llvm=no
make install with_llvm=no   # installs into ../pg-install/{share,lib}/...

echo
echo "Installed pgpdf into:"
echo "  $(pg_config --sharedir)/extension/"
echo "  $(pg_config --pkglibdir)/"
