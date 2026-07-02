#!/usr/bin/env bash
# Variables comunes para todos los scripts de ejecucion de casos de prueba.
# Sistema objetivo: Sistema-Para-Pruebas-Aseguramiento servido via `php -S localhost:8000`
BASE_URL="http://localhost:8000"
DB_SOCKET="/tmp/audit-mysql-run/mysql.sock"
DB_USER="root"
DB_PASS="root"
DB_NAME="security"

mysql_cli() {
  mariadb --socket="$DB_SOCKET" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" "$@"
}
