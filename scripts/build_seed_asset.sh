#!/usr/bin/env bash
# Ricostruisce il database iniziale (seed/build_seed.py, senza città) e lo
# copia tra gli asset dell'app: apps/niyah/assets/db/niyah_seed.db.
# Rilanciarlo e committare il risultato dopo ogni modifica a seed/.
#
# Uso: scripts/build_seed_asset.sh          (PYTHON=/percorso/python per scegliere l'interprete)
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

"$py" "$root/seed/build_seed.py" --out "$out"
mkdir -p "$(dirname "$asset")"
cp "$out" "$asset"
echo "Copiato in $asset"
