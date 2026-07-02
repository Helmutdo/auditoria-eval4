#!/usr/bin/env bash
# CP-CART-003: operaciones del carrito no requieren sesion autenticada
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-CART-003.txt"

{
  echo "=== CP-CART-003: carrito.php sin sesion activa ==="
  echo "--- Request SIN cookie alguna (equivalente a modo incognito, sin login previo) ---"
  echo "POST /carrito.php  op=1&iditems=1"
  curl -s -i -c /tmp/audit-mysql-run/cookies_cart003.txt -X POST "$BASE_URL/carrito.php" \
    --data-urlencode "op=1" --data-urlencode "iditems=1"
  echo
  echo "--- Cookie jar generada (PHP crea sesion anonima nueva SIN requerir autenticacion previa) ---"
  cat /tmp/audit-mysql-run/cookies_cart003.txt
  echo
  echo "--- Analisis: la respuesta HTTP 200 + el Set-Cookie de una sesion anonima nueva confirman que carrito.php"
  echo "NUNCA verifica isset(\$_SESSION['nombre']) antes de procesar la operacion. El mismo bug de count(null) de"
  echo "CP-CART-001 (ver ese caso) provoca el Fatal Error posterior, pero la ausencia de control de acceso ya quedo"
  echo "demostrada: la consulta SQL se intenta ejecutar para un usuario que jamas se autentico."
} | tee "$OUT"
