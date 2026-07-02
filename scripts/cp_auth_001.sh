#!/usr/bin/env bash
# CP-AUTH-001: Login rechaza credenciales invalidas y muestra mensaje de error
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-AUTH-001.txt"

{
  echo "=== CP-AUTH-001: credenciales invalidas ==="
  echo "--- Request ---"
  echo "POST /setup/procesalogin.php"
  echo "frmusuario=usuario_inexistente@test.cl&frmpassword=contraseñaincorrecta"
  echo
  echo "--- Response headers + body ---"
  curl -s -i -c /tmp/audit-mysql-run/cookies_auth001.txt \
    -X POST "$BASE_URL/setup/procesalogin.php" \
    --data-urlencode "frmusuario=usuario_inexistente@test.cl" \
    --data-urlencode "frmpassword=contraseñaincorrecta"
  echo
  echo "--- Cookie jar tras el intento ---"
  cat /tmp/audit-mysql-run/cookies_auth001.txt
} | tee "$OUT"
