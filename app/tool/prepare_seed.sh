#!/usr/bin/env bash
# Genera il database iniziale dell'app (assets/databases/niyah_seed.db) dai
# dati di seed/. Facoltativo: il primo argomento è cities15000.zip di GeoNames
# per la ricerca offline delle città.
#
#   app/tool/prepare_seed.sh                       # senza città
#   app/tool/prepare_seed.sh ~/Downloads/cities15000.zip
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
args=(--out "$root/app/assets/databases/niyah_seed.db")
if [[ $# -ge 1 ]]; then args+=(--cities "$1"); fi
python3 "$root/seed/build_seed.py" "${args[@]}"
