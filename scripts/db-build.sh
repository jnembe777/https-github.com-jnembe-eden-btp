#!/usr/bin/env bash
# ============================================================================
# EdenFin — Runner de build base de données (pipeline unifié)
# ----------------------------------------------------------------------------
# Applique, dans l'ordre de db/manifest.txt, tous les scripts SQL qui composent
# la base EdenFin (socle JASPE + migrations + gammes). Pensé pour le poste de
# dev et la CI, où PostgreSQL est « nu » (sans la couche Supabase).
#
# USAGE :
#   DATABASE_URL="postgres://user:pass@host:port/db" scripts/db-build.sh
#   # ou via les variables libpq classiques (PGHOST/PGPORT/PGUSER/PGDATABASE)
#
# VARIABLES :
#   DATABASE_URL     Chaîne de connexion psql (prioritaire si définie).
#   EDENFIN_DB_SHIM  1 (défaut) => applique d'abord le shim Supabase local/CI.
#                    0          => n'applique PAS le shim (cible Supabase réelle).
#   MANIFEST         Chemin du manifeste (défaut: db/manifest.txt).
#
# Sortie non nulle au premier script en erreur (ON_ERROR_STOP).
# ============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MANIFEST="${MANIFEST:-db/manifest.txt}"
SHIM="db/shim/00_supabase_compat.sql"
EDENFIN_DB_SHIM="${EDENFIN_DB_SHIM:-1}"

# psql de base : -v ON_ERROR_STOP=1 pour échouer franchement.
PSQL=(psql -v ON_ERROR_STOP=1 -X -q)
if [[ -n "${DATABASE_URL:-}" ]]; then
  PSQL+=(-d "$DATABASE_URL")
fi

run() {
  local f="$1"
  [[ -f "$f" ]] || { echo "::error:: fichier introuvable: $f"; exit 2; }
  echo "  ▸ $f"
  "${PSQL[@]}" -f "$f"
}

echo "== EdenFin db-build =="
echo "   manifest : $MANIFEST"
echo "   shim     : $([[ "$EDENFIN_DB_SHIM" == "1" ]] && echo "oui (local/CI)" || echo "non (Supabase réel)")"

if [[ "$EDENFIN_DB_SHIM" == "1" ]]; then
  echo "-- Shim de compatibilité Supabase"
  run "$SHIM"
fi

# EDENFIN_SKIP : liste de sous-chaînes (séparées par des virgules) ; tout fichier
# du manifeste dont le chemin contient l'une d'elles est ignoré. Sert au build de
# test (ex. EDENFIN_SKIP="03b-client-seed,06-seed-data" pour une base sans les
# données de démonstration, les tests pgTAP fournissant leurs propres fixtures).
EDENFIN_SKIP="${EDENFIN_SKIP:-}"
IFS=',' read -ra SKIP_PATTERNS <<< "$EDENFIN_SKIP"

should_skip() {
  local f="$1" pat
  for pat in "${SKIP_PATTERNS[@]}"; do
    pat="$(echo "$pat" | xargs || true)"
    [[ -n "$pat" && "$f" == *"$pat"* ]] && return 0
  done
  return 1
}

echo "-- Application du manifeste"
[[ -n "$EDENFIN_SKIP" ]] && echo "   skip     : $EDENFIN_SKIP"
# Lit le manifeste en ignorant commentaires et lignes vides.
while IFS= read -r line; do
  line="${line%%#*}"                     # retire les commentaires en fin de ligne
  line="$(echo "$line" | xargs || true)" # trim
  [[ -z "$line" ]] && continue
  if should_skip "$line"; then
    echo "  ⤷ (sauté) $line"
    continue
  fi
  run "$line"
done < "$MANIFEST"

echo "== Build terminé avec succès =="
