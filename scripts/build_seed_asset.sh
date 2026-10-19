#!/usr/bin/env bash
# Ricostruisce il database iniziale (seed/build_seed.py) e lo copia tra gli
# asset dell'app: apps/niyah/assets/db/niyah_seed.db.
# Rilanciarlo e committare il risultato dopo ogni modifica a seed/.
#
# Uso: scripts/build_seed_asset.sh cities15000.zip
#   cities15000.zip: https://download.geonames.org/export/dump/ (CC-BY 4.0).
#   L'app cerca la città degli orari di preghiera in questa tabella: l'asset
#   committato va sempre costruito con le città. Senza argomento lo script
#   si ferma, a meno di SEED_NO_CITIES=1 (solo per prove locali).
#   PYTHON=/percorso/python per scegliere l'interprete.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/seed/build/niyah_seed.db"
asset="$root/apps/niyah/assets/db/niyah_seed.db"

py="${PYTHON:-}"
if [ -z "$py" ]; then
  # Su Windows "python" può essere solo l'alias del Microsoft Store: si prova davvero.
  for c in python3 python py; do
    if "$c" -c 'import sys; sys.exit(sys.version_info < (3, 10))' >/dev/null 2>&1; then
      py="$c"
      break
    fi
  done
fi
if [ -z "$py" ]; then
  echo "ERRORE: serve Python >= 3.10 (oppure PYTHON=/percorso/python)" >&2
  exit 1
fi

cities="${1:-}"
if [ -n "$cities" ]; then
  "$py" "$root/seed/build_seed.py" --out "$out" --cities "$cities"
elif [ "${SEED_NO_CITIES:-}" = "1" ]; then
  "$py" "$root/seed/build_seed.py" --out "$out"
else
  echo "ERRORE: passa cities15000.zip di GeoNames (oppure SEED_NO_CITIES=1)" >&2
  exit 1
fi
mkdir -p "$(dirname "$asset")"
cp "$out" "$asset"
echo "Copiato in $asset"
