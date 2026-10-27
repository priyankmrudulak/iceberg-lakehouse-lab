#!/usr/bin/env bash
# download_data.sh — fetch the lab's sample data into data/raw/ (git-ignored).
#
# Data: NYC Taxi & Limousine Commission (TLC) Yellow Taxi trip records, published
# as Parquet files (~50 MB per month), plus the taxi zone lookup CSV.
# Source: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
#
# Each file's SHA-256 is pinned, so everyone gets byte-identical data. If TLC ever
# republishes a file, the check fails loudly instead of silently changing results.

set -euo pipefail
cd "$(dirname "$0")/.."

BASE=https://d37ci6vzurychx.cloudfront.net
DEST=data/raw
mkdir -p "$DEST"

# path on the server | sha256
FILES="
trip-data/yellow_tripdata_2024-01.parquet|c4d59da7bbc8abaeeeb1727947ee93d9891a71acb42854bd80db1571b2030510
trip-data/yellow_tripdata_2024-02.parquet|c76c43c18c6c6664080dd920baab4928988d5786a6b65980792ca7cd796f9f20
misc/taxi_zone_lookup.csv|1a99e105092230f8620f301edcca7f80d3080642ff404d28ed957d3fa222c8ed
"

for entry in $FILES; do
  path="${entry%%|*}"; sha="${entry##*|}"; file="$DEST/$(basename "$path")"
  if [ -f "$file" ] && echo "$sha  $file" | shasum -a 256 -c - >/dev/null 2>&1; then
    echo "✔ $file (already downloaded)"
    continue
  fi
  echo "↓ $file"
  curl -fL --progress-bar -o "$file.part" "$BASE/$path"
  if echo "$sha  $file.part" | shasum -a 256 -c - >/dev/null 2>&1; then
    mv "$file.part" "$file"; echo "✔ $file"
  else
    rm -f "$file.part"; echo "✘ checksum mismatch for $path" >&2; exit 1
  fi
done
