# Auditoria de Software - Evaluación 4

Repositorio de evidencia de la Auditoría de Software — INACAP, Evaluación 4 (Parte 2: Ejecución de Pruebas).

Contiene la evidencia de ejecución de los 10 casos de prueba diseñados en la Evaluación 3 - Parte 1
(Informe de Especificación y Diseño) contra el sistema real **Sistema-Para-Pruebas-Aseguramiento**
("Carta Digital para Restaurantes"). Este repo cumple el criterio 3.1.4 (Herramientas de soporte:
Git) de la pauta, dejando trazabilidad de cada caso ejecutado mediante commits individuales.

> El sistema auditado (`Sistema-Para-Pruebas-Aseguramiento`) es un repositorio aparte, de solo
> lectura para efectos de esta auditoría. Ningún archivo de ese sistema fue modificado ni tiene
> commits asociados a este trabajo.

## Estructura

```
auditoria-eval4/
  scripts/          Scripts bash que automatizan cada caso de prueba (curl + consultas SQL)
  evidencia/         Una carpeta por caso (CP-AUTH-001 ... CP-CART-003) con capturas de pantalla
  resultados/
    raw_CP-*.txt         Salida cruda (headers HTTP + body + queries SQL) de cada script ejecutado
    resultados_ejecucion.md   Informe consolidado: resultado real por caso, discrepancias vs.
                              el análisis estático de Parte 1, y estado del entorno de prueba
```

### Capturas de pantalla disponibles

| Caso | Archivos en `evidencia/` | Qué muestran |
|---|---|---|
| CP-AUTH-002 | `01_payload_ingresado.jpeg`, `02_bypass_login_exitoso.jpeg` | Payload SQLi en el formulario y bypass de login exitoso ("Bienvenido :Administrador") |
| CP-AUTH-003 | `01_passwords_texto_plano.jpeg` | Tabla `usuarios` vía cliente SQL mostrando contraseñas en texto plano |
| CP-AUTH-004 | `01_phpsessid_antes_login.jpeg`, `02_phpsessid_despues_login_identico.jpeg` | `PHPSESSID` idéntico antes/después del login (DevTools → Application → Cookies) |
| CP-COM-001 | `01_alert_ejecutado.jpeg` | `alert()` del XSS almacenado ejecutándose en el navegador |
| CP-CART-002 | `01_csrf_ejecutado_fetch.jpeg`, `02_sesion_destruida_tras_csrf.jpeg` | Ataque CSRF vía `fetch()` y sesión destruida al recargar |

Los demás casos (CP-AUTH-001, CP-COM-002, CP-COM-003, CP-CART-001, CP-CART-003) quedaron
completamente verificados con evidencia cruda HTTP/SQL en `resultados/raw_CP-*.txt`, sin
necesitar captura visual adicional.

## Casos de prueba cubiertos

| Módulo | Casos |
|---|---|
| Autenticación | CP-AUTH-001, CP-AUTH-002, CP-AUTH-003, CP-AUTH-004 |
| Gestión de Comentarios | CP-COM-001, CP-COM-002, CP-COM-003 |
| Carrito de Compras | CP-CART-001, CP-CART-002, CP-CART-003 |

Detalle completo de objetivo, payload, resultado real y veredicto de cada uno en
[`resultados/resultados_ejecucion.md`](resultados/resultados_ejecucion.md).

## Entorno de ejecución

- PHP 8.5.8 vía servidor embebido (`php -d extension=mysqli -S localhost:8000`), extensión `mysqli`
  cargada en tiempo de ejecución sin modificar `php.ini` del sistema.
- MariaDB 12.3.2 con datadir propio de usuario (sin `systemd`, sin tocar `/var/lib/mysql`), socket en
  `/tmp/audit-mysql-run/mysql.sock`.
- Base de datos `security` importada sin cambios desde `basedatos/security.sql` del repo objetivo.

## Cómo reproducir

```bash
# 1. Levantar MariaDB local (datadir propio) y el servidor PHP embebido
#    apuntando a Sistema-Para-Pruebas-Aseguramiento (ver detalle en resultados_ejecucion.md)

# 2. Ejecutar cada caso
bash scripts/cp_auth_001.sh
bash scripts/cp_auth_002.sh
bash scripts/cp_auth_003.sh
bash scripts/cp_auth_004.sh
bash scripts/cp_com_001.sh
bash scripts/cp_com_002.sh
bash scripts/cp_com_003.sh
bash scripts/cp_cart_001.sh
bash scripts/cp_cart_002.sh
bash scripts/cp_cart_003.sh
```

Cada script imprime su evidencia por stdout y la guarda en `resultados/raw_CP-*.txt`.

## Hallazgos principales (resumen)

8 de los 10 casos confirman exactamente el hallazgo previsto en el análisis estático de Parte 1
(SQL Injection en login y carrito, XSS almacenado, CSRF, contraseñas en texto plano, Session
Fixation, falta de control de acceso). 2 casos (CP-COM-003 y matices en CP-COM-002/CP-CART-001)
revelaron diferencias relevantes entre el análisis estático y el comportamiento real en PHP 8 —
documentadas en detalle en `resultados/resultados_ejecucion.md`.
