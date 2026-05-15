#!/usr/bin/env bash
# Run an arbitrary PDF through pgpdf and produce three artefacts next to it:
#   <file>.pgpdf.txt    raw concatenated text (what `pdf_read_file` returns)
#   <file>.pgpdf.csv    one row per page: page, text   (CSV with header)
#   <file>.pgpdf.meta   title/author/etc. as key=value lines
#
# Usage: ./run-pdf.sh path/to/file.pdf
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$PWD/pg-install/bin:$PATH"

PDF="${1:-}"
if [[ -z "$PDF" || ! -f "$PDF" ]]; then
  echo "usage: $0 path/to/file.pdf" >&2
  exit 2
fi
PDF=$(readlink -f "$PDF")
BASE="${PDF%.pdf}"

export PGPORT="${PGPORT:-55432}"
PSQL=(psql -h /tmp -p "$PGPORT" -U "$USER" -d postgres -X -v ON_ERROR_STOP=1)

"${PSQL[@]}" -c "CREATE EXTENSION IF NOT EXISTS pgpdf;" >/dev/null

echo "=== $PDF ==="

# Metadata to a key=value sidecar (and echo to stdout).
"${PSQL[@]}" -At <<SQL | tee "$BASE.pgpdf.meta"
SELECT 'title='        || COALESCE(pdf_title('$PDF'::pdf), '');
SELECT 'author='       || COALESCE(pdf_author('$PDF'::pdf), '');
SELECT 'creator='      || COALESCE(pdf_creator('$PDF'::pdf), '');
SELECT 'subject='      || COALESCE(pdf_subject('$PDF'::pdf), '');
SELECT 'keywords='     || COALESCE(pdf_keywords('$PDF'::pdf), '');
SELECT 'pdf_version='  || COALESCE(pdf_version('$PDF'::pdf), '');
SELECT 'pages='        || pdf_num_pages('$PDF'::pdf)::text;
SELECT 'creation='     || COALESCE(pdf_creation('$PDF'::pdf)::text, '');
SELECT 'modification=' || COALESCE(pdf_modification('$PDF'::pdf)::text, '');
SQL

# Raw concatenated text (what pdf_read_file / pdf_out returns).
"${PSQL[@]}" -At -c "SELECT '$PDF'::pdf::text;" > "$BASE.pgpdf.txt"

# Per-page CSV. We read the PDF once via a CTE so we don't re-parse for each page.
"${PSQL[@]}" --csv <<SQL > "$BASE.pgpdf.csv"
WITH doc AS (SELECT '$PDF'::pdf AS p)
SELECT g.n + 1                AS page,
       pdf_page(p, g.n)       AS text
FROM   doc, generate_series(0, pdf_num_pages(p) - 1) g(n)
ORDER BY g.n;
SQL

echo "--- wrote ---"
ls -la "$BASE.pgpdf.txt" "$BASE.pgpdf.csv" "$BASE.pgpdf.meta"
