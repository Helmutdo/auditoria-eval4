#!/usr/bin/env bash
# CP-AUTH-003: Verificar que las contraseñas estan protegidas con hash criptografico
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
OUT="$DIR/../resultados/raw_CP-AUTH-003.txt"

{
  echo "=== CP-AUTH-003: almacenamiento de contraseñas en BD 'security', tabla usuarios ==="
  echo "--- Consulta SQL ejecutada directamente contra MariaDB (acceso equivalente al de un atacante con acceso a la BD, ej. via SQLi de CP-CART-001) ---"
  echo "SELECT Id, nombre, email, password, estado FROM usuarios;"
  echo
  mysql_cli -e "SELECT Id, nombre, email, password, estado FROM usuarios;"
  echo
  echo "--- Analisis: se verifica si el campo password matchea un formato de hash conocido (bcrypt \$2y\$, sha256, argon2 \$argon2) ---"
  mysql_cli -N -e "SELECT password FROM usuarios;" | while read -r pwd; do
    if [[ "$pwd" =~ ^\$2[aby]\$ ]] || [[ "$pwd" =~ ^\$argon2 ]] || [[ ${#pwd} -eq 64 ]]; then
      echo "  '$pwd' -> PARECE HASH"
    else
      echo "  '$pwd' -> TEXTO PLANO (no es hash)"
    fi
  done
} | tee "$OUT"
