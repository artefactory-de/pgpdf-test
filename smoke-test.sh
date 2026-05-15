#!/usr/bin/env bash
# Smoke test: load pgpdf, run it on a small public-domain PDF, print
# metadata + first-page excerpt to confirm the toolchain is sane.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$PWD/pg-install/bin:$PATH"
export PGPORT="${PGPORT:-55432}"
PSQL=(psql -h /tmp -p "$PGPORT" -U "$USER" -d postgres -X -v ON_ERROR_STOP=1)

PDF="$PWD/test-pdfs/pgintro.pdf"
if [[ ! -f "$PDF" ]]; then
  curl -fsSL -o "$PDF" \
    https://wiki.postgresql.org/images/e/ea/PostgreSQL_Introduction.pdf
fi

"${PSQL[@]}" -c "DROP EXTENSION IF EXISTS pgpdf; CREATE EXTENSION pgpdf;"

echo "--- metadata ---"
"${PSQL[@]}" -c "SELECT pdf_title('$PDF'::pdf), pdf_author('$PDF'::pdf), pdf_num_pages('$PDF'::pdf), pdf_version('$PDF'::pdf);"

echo "--- first 500 chars ---"
"${PSQL[@]}" -At -c "SELECT substring('$PDF'::pdf::text, 1, 500);"
