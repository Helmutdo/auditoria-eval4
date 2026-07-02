#!/usr/bin/env bash
# CP-AUTH-004: Verificar regeneracion del ID de sesion tras autenticacion exitosa
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-AUTH-004.txt"
JAR=/tmp/audit-mysql-run/cookies_auth004.txt
rm -f "$JAR"

{
  echo "=== CP-AUTH-004: Session Fixation ==="
  echo "--- Paso 1: GET index.php (pre-login), registrar PHPSESSID ---"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null "$BASE_URL/index.php"
  PRE=$(grep PHPSESSID "$JAR" | awk '{print $7}')
  echo "PHPSESSID antes del login: $PRE"
  echo
  echo "--- Paso 2: POST setup/procesalogin.php con admin@gmail.com / admin01, reutilizando la MISMA cookie ---"
  curl -s -i -c "$JAR" -b "$JAR" -X POST "$BASE_URL/setup/procesalogin.php" \
    --data-urlencode "frmusuario=admin@gmail.com" \
    --data-urlencode "frmpassword=admin01"
  echo
  echo "--- Paso 3: PHPSESSID despues del login (jar completo) ---"
  cat "$JAR"
  POST=$(grep PHPSESSID "$JAR" | tail -1 | awk '{print $7}')
  echo
  echo "PHPSESSID antes:   $PRE"
  echo "PHPSESSID despues: $POST"
  if [[ "$PRE" == "$POST" ]]; then
    echo "RESULTADO: el ID de sesion NO cambio -> Session Fixation confirmada"
  else
    echo "RESULTADO: el ID de sesion SI cambio -> mitigacion presente"
  fi
} | tee "$OUT"
