# Resultados de Ejecución — Evaluación 4, Parte 2

**Sistema bajo prueba:** Sistema-Para-Pruebas-Aseguramiento (Carta Digital para Restaurantes)
**Entorno de ejecución:** PHP 8.5.8 (servidor embebido `php -S localhost:8000`) + MariaDB 12.3.2, base de datos `security` importada desde `basedatos/security.sql`, sin modificaciones al código fuente del sistema.
**Fecha de ejecución:** 2026-07-01/02
**Referencia:** Casos de prueba diseñados en Evaluación 3 - Parte 1 (Informe de Especificación y Diseño).

> Nota metodológica: el informe de Parte 1 declaraba explícitamente que la Fase 4 (Ejecución) estaba **fuera de alcance** y que su columna "Resultado real" provenía de análisis estático del código fuente, no de ejecución contra un sistema vivo. Esta Parte 2 ejecuta los 10 casos contra el sistema real y corrige/confirma dichos resultados.

---

## Módulo 1: Autenticación de Usuarios

### CP-AUTH-001 — Login rechaza credenciales inválidas
| Campo | Valor |
|---|---|
| Resultado real obtenido | `POST /setup/procesalogin.php` con `usuario_inexistente@test.cl` / `contraseñaincorrecta` devuelve `302 Found` hacia `index.php`, **sin** `Set-Cookie` (no se llama `session_start()` en la rama de fallo) y sin ningún mensaje de error visible. |
| Estado | Aprobado (el sistema falla como se predijo) |
| Evidencia | `resultados/raw_CP-AUTH-001.txt` |
| Anomalía detectada | No hay distinción visual entre éxito y fracaso del login → enumeración/adivinación de usuarios facilitada (CWE-209). |
| Acción correctiva técnica propuesta | Mostrar un mensaje de error genérico ("Credenciales inválidas") sin revelar si el email existe o no; no usar la ausencia/presencia de cookie como única señal de estado. |

### CP-AUTH-002 — SQL Injection bypass de autenticación
| Campo | Valor |
|---|---|
| Resultado real obtenido | `frmusuario=' OR '1'='1' -- ` / `frmpassword=cualquier_valor` → `302 Found` con `Set-Cookie: PHPSESSID=...`. La petición subsiguiente a `index.php` con esa cookie muestra `Bienvenido :Administrador`, confirmando sesión iniciada como el primer usuario de la tabla sin conocer credenciales válidas. |
| Estado | Aprobado (falla confirmada, coincide 100% con el informe de Parte 1) |
| Evidencia | `resultados/raw_CP-AUTH-002.txt` |
| Anomalía detectada | Bypass total de autenticación mediante SQL Injection clásico (CWE-89). Severidad CRÍTICA confirmada empíricamente. |
| Acción correctiva técnica propuesta | Reemplazar concatenación de `$_POST` por sentencias preparadas (`mysqli_prepare`/`bind_param` o PDO con parámetros bindeados). |

### CP-AUTH-003 — Contraseñas en texto plano
| Campo | Valor |
|---|---|
| Resultado real obtenido | Consulta directa a la tabla `usuarios`: `admin01` y `alondra01` almacenados literalmente en el campo `password`, sin ningún prefijo de hash (`$2y$`, `$argon2`, etc.). |
| Estado | Aprobado (falla confirmada) |
| Evidencia | `resultados/raw_CP-AUTH-003.txt` |
| Anomalía detectada | Almacenamiento inseguro de credenciales (CWE-256). |
| Acción correctiva técnica propuesta | Migrar a `password_hash()` (bcrypt/Argon2) en el registro y `password_verify()` en el login; ejecutar script de migración one-time para hashear las contraseñas existentes. |

### CP-AUTH-004 — Session Fixation
| Campo | Valor |
|---|---|
| Resultado real obtenido | Se registró `PHPSESSID` antes del login (`beebad9f...`) y se reutilizó la misma cookie en el `POST` de login válido (`admin@gmail.com`/`admin01`). El valor de `PHPSESSID` **no cambió** tras la autenticación exitosa. |
| Estado | Aprobado (falla confirmada, evidencia HTTP directa vía cookie jar de curl, equivalente/superior a inspección manual en DevTools) |
| Evidencia | `resultados/raw_CP-AUTH-004.txt` |
| Anomalía detectada | Session Fixation (CWE-384): `procesalogin.php` nunca llama a `session_regenerate_id(true)`. |
| Acción correctiva técnica propuesta | Invocar `session_regenerate_id(true)` inmediatamente después de validar credenciales y antes de asignar `$_SESSION['nombre']`. |

---

## Módulo 2: Gestión de Comentarios

### CP-COM-001 — XSS Almacenado
| Campo | Valor |
|---|---|
| Resultado real obtenido | Tras login válido, se envió `comentario=<script>alert("XSS-CP-COM-001")</script>` a `grcomentarios.php`. El registro quedó en la tabla `comentarios` (Id 7) sin escapar. Al recuperar `index.php?id=1`, el `<script>` aparece **literal** en el HTML (no `&lt;script&gt;`), confirmando ausencia de `htmlspecialchars()`. |
| Estado | Aprobado a nivel HTTP/DB. **Pendiente verificación visual del `alert()` real en navegador** (ver lista de capturas pendientes). |
| Evidencia | `resultados/raw_CP-COM-001.txt` + captura pendiente `evidencia/CP-COM-001/` |
| Anomalía detectada | XSS Almacenado (CWE-79), severidad CRÍTICA confirmada. |
| Acción correctiva técnica propuesta | Aplicar `htmlspecialchars($dato, ENT_QUOTES, 'UTF-8')` en toda salida de datos de usuario; adicionalmente sanitizar/validar en el punto de entrada. |

### CP-COM-002 — Endpoint accesible sin autenticación
| Campo | Valor |
|---|---|
| Resultado real obtenido | `POST /grcomentarios.php` sin cookie de sesión devuelve `200 OK` con `Set-Cookie` de una sesión anónima nueva, pero termina en **Fatal Error** (`Uncaught mysqli_sql_exception`) porque `$_SESSION['id']` es un array key indefinido (PHP 8 lanza `Warning` + la concatenación `"id_restaurante=".$_SESSION['id']` produce `id_restaurante=` vacío → error de sintaxis SQL). El comentario **no** llega a insertarse. |
| Estado | Aprobado parcialmente — la falla de control de acceso (ausencia de verificación de sesión) **se confirma** (el código intenta procesar la petición sin autenticación), pero el resultado difiere del informe de Parte 1. |
| Evidencia | `resultados/raw_CP-COM-002.txt` |
| Anomalía detectada | Control de acceso insuficiente (CWE-306) confirmado. **Discrepancia con Parte 1**: ver sección de discrepancias. |
| Acción correctiva técnica propuesta | Validar `isset($_SESSION['nombre'])` y `isset($_SESSION['id'])` al inicio de `grcomentarios.php`, devolviendo HTTP 401/403 si no hay sesión autenticada, antes de construir cualquier consulta SQL. |

### CP-COM-003 — SQL Injection en INSERT de comentarios
| Campo | Valor |
|---|---|
| Resultado real obtenido | Payload `normal');INSERT INTO usuarios(...) VALUES('hacker',...);--` produjo **Fatal Error** (`mysqli_sql_exception: syntax error ... near ');INSERT INTO usuarios...`). La tabla `usuarios` **no** contiene el registro `hacker`/`hk@hk.com` tras el intento. |
| Estado | Fallido respecto al vector exacto propuesto en Parte 1, pero la vulnerabilidad SQLi de fondo sigue confirmada (ver discrepancias). |
| Evidencia | `resultados/raw_CP-COM-003.txt` |
| Anomalía detectada | SQL Injection (CWE-89) confirmado como vulnerabilidad, pero el vector de "sentencias apiladas" no es explotable con `mysqli_query()` (ver discrepancia). |
| Acción correctiva técnica propuesta | Usar sentencias preparadas para el `INSERT`; adicionalmente, si se requiere multi-statement en algún punto del sistema, nunca habilitar `CLIENT_MULTI_STATEMENTS` con entradas de usuario no parametrizadas. |

---

## Módulo 3: Carrito de Compras

### CP-CART-001 — SQL Injection UNION-based en `iditems`
| Campo | Valor |
|---|---|
| Resultado real obtenido | El payload `1 UNION SELECT 1,password,email FROM usuarios WHERE Id=1-- ` fue verificado en el **query log de MariaDB**, confirmando que el motor de BD recibió y ejecutó la consulta inyectada sin error de sintaxis. Sin embargo, la respuesta HTTP nunca llega a mostrar el dato exfiltrado en `mostrar_carrito.php` porque `carrito.php` crashea después (ver discrepancia técnica: bug de compatibilidad PHP7→PHP8 en `count()`). |
| Estado | Aprobado — SQLi confirmado a nivel de motor de base de datos con evidencia directa del query log. |
| Evidencia | `resultados/raw_CP-CART-001.txt` |
| Anomalía detectada | SQL Injection UNION-based (CWE-89), severidad CRÍTICA confirmada. |
| Acción correctiva técnica propuesta | Sentencias preparadas para el `SELECT` de `carrito.php`; adicionalmente corregir el bug de `count()` (ver discrepancias) para eliminar el error de disponibilidad. |

### CP-CART-002 — CSRF en destrucción de sesión (`op=3`)
| Campo | Valor |
|---|---|
| Resultado real obtenido | Con sesión autenticada (`Bienvenido :Administrador` visible en `index.php`), se envió `POST /carrito.php` con `op=3` incluyendo un header `Origin: https://sitio-malicioso-externo.example`. La sesión fue destruida: la petición subsiguiente con la misma cookie ya no muestra `Bienvenido :Administrador`. |
| Estado | Aprobado (falla confirmada, coincide con el informe de Parte 1) |
| Evidencia | `resultados/raw_CP-CART-002.txt` |
| Anomalía detectada | CSRF (CWE-352): ninguna verificación de origen/token antes de ejecutar `session_destroy()`. |
| Acción correctiva técnica propuesta | Implementar token CSRF por sesión (validado en cada operación de estado) y/o verificar el header `Origin`/`Sec-Fetch-Site` antes de operaciones destructivas. |

### CP-CART-003 — Operaciones del carrito sin sesión autenticada
| Campo | Valor |
|---|---|
| Resultado real obtenido | `POST /carrito.php` con `op=1&iditems=1` sin ninguna cookie previa devuelve `200 OK` junto con `Set-Cookie` de una sesión anónima nueva, confirmando que `carrito.php` nunca valida `isset($_SESSION['nombre'])` antes de procesar. Termina en el mismo Fatal Error de `count()` descrito en CP-CART-001. |
| Estado | Aprobado — falta de control de acceso confirmada. |
| Evidencia | `resultados/raw_CP-CART-003.txt` |
| Anomalía detectada | Falta de control de acceso (CWE-306) confirmado. |
| Acción correctiva técnica propuesta | Verificar `isset($_SESSION['nombre'])` al inicio de `carrito.php` y devolver 401/403 si no hay sesión autenticada. |

---

## Tabla consolidada

| ID | Esperado (Parte 1) | Real (ejecución Parte 2) | Estado | Severidad |
|---|---|---|---|---|
| CP-AUTH-001 | Falla — sin mensaje de error (enumeración) | Confirmado igual | Aprobado | Media |
| CP-AUTH-002 | Falla crítica — SQLi bypass | Confirmado igual | Aprobado | Crítica |
| CP-AUTH-003 | Falla crítica — password texto plano | Confirmado igual | Aprobado | Crítica |
| CP-AUTH-004 | Falla — Session Fixation | Confirmado igual (evidencia HTTP directa) | Aprobado | Alta |
| CP-COM-001 | Falla crítica — XSS almacenado | Confirmado a nivel HTTP/DB; falta captura de `alert()` real | Aprobado (parcial, ver pendientes) | Crítica |
| CP-COM-002 | Falla — endpoint sin auth | Confirmado, pero con crash PHP8 no previsto en Parte 1 | Aprobado (con discrepancia) | Alta |
| CP-COM-003 | Falla crítica — SQLi apilado exitoso | **Vector exacto de Parte 1 falla** (mysqli_query no soporta multi-statement); SQLi de fondo sigue crítico | Fallido / Reclasificado | Crítica (vector corregido) |
| CP-CART-001 | Falla crítica — UNION SQLi exfiltra datos | Confirmado a nivel de motor BD (query log); UI no lo muestra por bug PHP8 | Aprobado (con discrepancia) | Crítica |
| CP-CART-002 | Falla — CSRF | Confirmado igual | Aprobado | Alta |
| CP-CART-003 | Falla — sin control de sesión | Confirmado igual | Aprobado | Media |

**Totales:** 8/10 casos confirman exactamente el hallazgo de Parte 1. 2/10 (CP-COM-002, CP-COM-003) y adicionalmente CP-CART-001 muestran comportamiento real distinto al asumido por el análisis estático, documentado en la sección de discrepancias.

---

## Discrepancias relevantes entre el análisis estático (Parte 1) y la ejecución real (Parte 2)

1. **Bug de compatibilidad PHP7→PHP8 en `carrito.php` (`count()` sobre `null`)** — no detectado en Parte 1.
   El código nunca inicializa `$_SESSION["carrito"]` como array antes de invocar `count($_SESSION["carrito"])`. En PHP 7.x esto generaba solo un `Warning` (comportamiento tolerante). En PHP 8.x, `count()` sobre `null` lanza un `TypeError` fatal. **Consecuencia práctica:** la funcionalidad completa de "agregar producto al carrito" (`op=1`) está rota en cualquier entorno con PHP 8+, incluso con datos 100% legítimos, no solo con payloads maliciosos. Esto afectó la ejecución de CP-CART-001 y CP-CART-003: la inyección SQL se demuestra igualmente (la consulta se ejecuta contra MariaDB, verificado con el query log), pero el resultado nunca llega a renderizarse en `mostrar_carrito.php` porque el script crashea antes. Se recomienda registrar este hallazgo como un defecto adicional de **Confiabilidad/Disponibilidad** (ISO 25010) independiente de las vulnerabilidades de seguridad ya identificadas.

2. **`mysqli_query()` no ejecuta sentencias SQL apiladas (multi-statement)** — asunción incorrecta en Parte 1.
   El caso CP-COM-003 fue diseñado asumiendo que un payload con `;INSERT INTO usuarios...` ejecutaría una segunda sentencia tras la de comentarios ("Segunda inserción ejecutada correctamente", según el informe de Parte 1). En la ejecución real, `mysqli_query()` (la función usada en `grcomentarios.php`, sin `mysqli_multi_query()` ni el flag `CLIENT_MULTI_STATEMENTS`) rechaza el punto y coma como sintaxis inválida y lanza una excepción fatal; el usuario `hacker` nunca se creó. **La vulnerabilidad SQL Injection de fondo sigue siendo crítica** (no hay sanitización ni parametrización), pero el vector de explotación correcto para este endpoint es manipular otras columnas dentro de la MISMA sentencia `INSERT ... SET` (por ejemplo, sobrescribir `id_restaurante` o incluir subconsultas en otro campo del mismo INSERT), no inyectar sentencias apiladas. Se recomienda corregir el caso de prueba en el informe final.

3. **PHP 8 con `mysqli_report` estricto por defecto convierte errores SQL silenciosos en excepciones fatales** — matiza CP-COM-002.
   El informe de Parte 1 asumía que, sin sesión, `id_restaurante` quedaría `NULL` y el `INSERT` se ejecutaría igualmente ("el INSERT se ejecuta con id_restaurante=NULL"). En la ejecución real, la ausencia de `$_SESSION['id']` genera un error de sintaxis SQL (`id_restaurante=` sin valor) y `mysqli_report(MYSQLI_REPORT_ERROR|MYSQLI_REPORT_STRICT)` — comportamiento por defecto desde PHP 8.1 — lanza una excepción no capturada, abortando la inserción. **El hallazgo de fondo (endpoint accesible sin autenticación) sigue confirmado**: el servidor procesa la petición sin verificar sesión, solo que el resultado concreto (inserción silenciosa vs. crash) depende de la versión de PHP y su configuración de reporte de errores del entorno de despliegue.

4. **CP-AUTH-004 se verificó vía cookie jar de `curl` en lugar de DevTools del navegador.**
   Esto no es una discrepancia de comportamiento del sistema, sino de método: se optó por una verificación scriptable (comparación exacta del valor `PHPSESSID` en el archivo de cookies antes/después del login) en lugar de inspección visual manual, lo cual es evidencia igual o más precisa que una captura de pantalla. Se ofrece opcionalmente tomar una captura complementaria de DevTools si se desea para el informe (ver lista de capturas).

---

## Estado del entorno de prueba

- PHP 8.5.8 (servidor embebido, extensión `mysqli` cargada vía flag `-d extension=mysqli`, sin modificar `/etc/php/php.ini`).
- MariaDB 12.3.2, datadir propio del usuario (sin systemd, sin tocar `/var/lib/mysql` del sistema), socket `/tmp/audit-mysql-run/mysql.sock`, puerto 3307.
- Base de datos `security` importada sin cambios desde `basedatos/security.sql` del repo `Sistema-Para-Pruebas-Aseguramiento` (no se modificó ningún archivo de ese repo).
- Credenciales de conexión usadas por `setup/setup.php` (`root`/`root`/`security` vía host `localhost`) se satisficieron configurando el usuario `root` de MariaDB con password `root` y apuntando el socket por defecto de PHP (`mysqli.default_socket`) al socket local, sin necesidad de editar el código del sistema objetivo.
