# Cuentas conectadas a los widgets

Estado: **implementado**, Google y iCloud. Falta que conectes tus cuentas (§2, §3).
Última actualización: 2026-08-27.

Google Calendar y Google Tasks van por OAuth. iCloud va por CalDAV, y el correo
—Gmail, iCloud y Proton, todos a la vez si querés— por IMAP.

---

## 1. Qué ves cuando esté conectado

- **Calendario** (pestaña de siempre): puntitos debajo de los días con eventos,
  del color del calendario al que pertenecen, con Google e iCloud mezclados.
  Pasando el mouse por un día aparece la lista de ese día con horarios.
- **Agenda** (pestaña nueva, sólo con alguna cuenta conectada): los próximos
  eventos en lista, de todos tus calendarios juntos.
- **To Do**: tus tareas de Google Tasks y tus Recordatorios de iCloud mezclados
  con los locales, con una marquita "☁ Google" / "☁ iCloud" en los remotos.
  Tildar o borrar uno remoto sube el cambio.
- **Mail** (pestaña nueva, sólo si lo activás): cuántos mails sin leer y de
  quién, de todas tus cuentas juntas y con los más nuevos arriba. Click abre el
  webmail que corresponde a esa cuenta.

Todo lo que se ve se abre de un click en el navegador: un día del calendario con
eventos abre ese día en la web, un evento de la agenda abre el evento, y las
tareas de la nube tienen un botón que abre Google Tasks o Recordatorios. Y todo
aparece al instante: lo último que se trajo queda cacheado en disco, así que la
barra recién arrancada no muestra widgets vacíos mientras espera la red.

---

## 2. Google: un click

**Ajustes → Perfil → Cuentas → Google → Conectar cuenta.** Se abre el navegador
y la página te lleva paso a paso, con un link directo a cada pantalla. Pegás las
dos credenciales *ahí* (no en el panel de la shell), la misma pestaña sigue sola
a la pantalla de permisos de Google y vuelve con la sesión hecha.

**Por qué hay pasos:** Google no deja usar sus APIs sin un cliente OAuth propio.
Eso no se puede saltear — pero se hace una sola vez y no se repite. Lo que la
página te va a pedir:

1. Crear un proyecto.
2. Habilitar **Calendar API** y **Tasks API**. (Gmail no: el correo va por IMAP.)
3. **Publishing status → In production.** No es opcional: en "Testing" Google
   vence el permiso a los 7 días y habría que reconectar todas las semanas. Como
   la app no está verificada vas a ver un aviso — *Advanced → Go to (unsafe)*.
   Es tu propia app.
4. Crear el cliente tipo **Desktop app** y pegar Client ID y Secret en la página.

Después de eso, **Volver a conectar** salta toda la guía y va directo al permiso.
El redirect es `http://127.0.0.1:8890/callback`; los clientes Desktop aceptan
cualquier puerto de loopback, así que no hay que registrarlo en ningún lado.

## 3. iCloud: un click

**Ajustes → Perfil → Cuentas → iCloud → Conectar cuenta.** Se abre el
navegador con una página que te explica, te linkea directo a donde se genera la
contraseña de aplicación, y verifica la credencial contra iCloud antes de
guardarla. Si no anda, te lo dice ahí mismo y probás de nuevo.

**Por qué no es un OAuth de verdad:** Apple no lo ofrece. "Iniciar sesión con
Apple" te loguea en *otros* sitios; no da acceso a tus datos de iCloud, y no hay
API pública de iCloud para terceros. Lo único que existe es CalDAV/IMAP con una
contraseña específica de app. Así que el flujo reproduce la *experiencia* del
OAuth —navegador, un click, verificado, ningún campo de secreto en el panel de
Ajustes— sobre el único transporte que Apple deja usar.

Del lado de Apple la contraseña se revoca cuando quieras, desde
https://account.apple.com → Iniciar sesión y seguridad → Contraseñas específicas
de la app. La shell no puede tocar tu cuenta más allá de olvidarla.

---

## 4. Correo: una o varias cuentas

**Ajustes → Perfil → Cuentas → Correo → Agregar Gmail / Agregar iCloud.**
Mismo flujo por navegador que §3, verificación incluida (hace login IMAP de
verdad y cuenta los mensajes). Podés tener las que quieras a la vez; cada una se
prende, se apaga o se borra por separado.

Para Gmail hace falta tener la verificación en dos pasos activa: sin eso Google
no deja generar contraseñas de aplicación. Proton tiene su propio requisito, el
Bridge: ver §4b.

Es una contraseña de APLICACIÓN, no la de tu cuenta. El buzón se abre en modo
lectura, así que mirar el widget nunca marca nada como leído.

> Si venías de la versión de una sola cuenta, sigue andando tal cual: se muestra
> como la cuenta `default` y conserva su contraseña. Al tocar las cuentas desde
> Ajustes se migra sola a la lista nueva.

---

## 4b. Proton Mail: hace falta el Bridge

**Ajustes → Perfil → Cuentas → Correo → Agregar Proton.** Mismo flujo por
navegador, pero con un requisito propio.

Proton no expone IMAP a internet, y no es una omisión: tu correo está cifrado de
punta a punta y sus servidores no pueden entregarlo en claro. El puente es
**Proton Mail Bridge**, que corre en tu máquina, descifra ahí mismo y levanta un
IMAP en `127.0.0.1:1143` con STARTTLS.

1. Instalá el Bridge — en Arch está en el AUR como `protonmail-bridge`
   ([qué es](https://proton.me/mail/bridge)).
2. Iniciá sesión con tu cuenta de Proton y abrí **Mailbox details**: ahí te da un
   usuario y una **contraseña del Bridge**. Esa es la que va en la página de
   conexión — no la de tu cuenta de Proton.
3. La página te avisa en el momento si el Bridge está escuchando o no, y te deja
   cambiar el puerto si el tuyo no usa el de fábrica.

> **El Bridge necesita un plan pago de Proton** (Mail Plus, Unlimited o
> Business). Con la cuenta gratis no hay IMAP posible, y no hay forma de rodearlo
> desde acá.

El certificado del Bridge se lo genera él mismo en cada instalación, así que no
hay CA que lo firme y la verificación se saltea — pero **sólo en loopback**, donde
el tráfico no sale de la máquina y no hay nada en el medio que interceptar. Un
servidor de internet nunca entra por ese camino: `is_loopback()` lo decide.

### Lo que Proton no puede dar

- **Proton Calendar** no habla CalDAV, ni siquiera a través del Bridge, que sólo
  expone correo. No hay forma de traer esos eventos al widget.
- **Proton Pass** no tiene API pública ni exporta en vivo. Tus contraseñas
  siguen donde están; la shell no las toca.

---

## 5. Scopes que se piden (Google)

```
https://www.googleapis.com/auth/userinfo.email     # para mostrar de qué cuenta es la sesión
https://www.googleapis.com/auth/calendar.readonly  # eventos
https://www.googleapis.com/auth/tasks              # tareas (lectura y escritura)
```

Gmail no aparece: ese scope (`gmail.readonly`) es *restricted*, el más sensible
que tiene Google, y pedirlo para mostrar un contador de no leídos no valía la
pena cuando IMAP hace lo mismo sin vencerse nunca.

El authorize URL lleva `access_type=offline` y `prompt=consent`. Sin el primero
Google no devuelve refresh token; sin el segundo deja de devolverlo del segundo
login en adelante, y te quedás con una sesión que muere en una hora.

---

## 6. Dónde quedó cada cosa

### Archivos nuevos

| Archivo | Qué hace |
|---|---|
| `scripts/google/auth.py` | Login OAuth: PKCE + servidor loopback de un solo request. Protocolo por stdout `AUTHURL`/`TOKENS`/`ERROR`. Verifica el `state` y aborta si Google no devolvió refresh token. |
| `scripts/accounts/connect.py` | Conexión por navegador para lo que no tiene OAuth (iCloud, contraseñas de app de Gmail). Mismo protocolo, con `CREDS` en vez de `TOKENS`. Verifica la credencial de verdad antes de devolverla. |
| `scripts/apple/caldav.py` | Cliente CalDAV: descubrimiento, eventos con ventana, recordatorios, y escritura con `If-Match`. Credenciales por variable de entorno. |
| `scripts/apple/_ical.py` | Parser de iCalendar y expansor de `RRULE` (incluye `EXDATE`, `COUNT`, `UNTIL`, `BYDAY`). |
| `scripts/mail/imap.py` | Lee no leídos por IMAP: SSL para Gmail/iCloud, STARTTLS contra el Bridge para Proton. Contraseña por variable de entorno (nunca por argv, que lo ve `ps`). Buzón en `readonly`. Decodifica encabezados MIME. |
| `services/GoogleAccount.qml` | Lo único que sabe de OAuth. `login`/`logout`/`renew`/`request`, reintento único ante 401, `needsReauth` cuando Google dice `invalid_grant`. |
| `services/GoogleCalendar.qml` | Eventos normalizados: `eventsByDate` y `upcoming`. Ventana móvil según el mes que estés mirando. |
| `services/GoogleTasks.qml` | Tareas. Escrituras optimistas: cambia en pantalla y revierte si el PATCH falla. |
| `services/AppleAccount.qml` | La cuenta de iCloud y la cola que corre `caldav.py`. Un proceso por vez: iCloud limita las peticiones simultáneas. |
| `services/AppleCalendar.qml` | Lo mismo que `GoogleCalendar`, con las mismas dos propiedades de salida. |
| `services/AppleReminders.qml` | Recordatorios, con la misma forma que `GoogleTasks`. Guarda el `etag` nuevo en cada escritura. |
| `services/Calendars.qml` | Mezcla los proveedores en un solo `eventsByDate`/`upcoming`. Es lo que leen los widgets. |
| `services/MailService.qml` | Varias cuentas IMAP, una por vez, mezcladas por fecha. También el flujo de conexión por navegador. |
| `services/AccountsCache.qml` | Lo último que trajo cada cuenta, en disco, para que los widgets pinten al instante. Es un cache: si no está, todo sigue igual pero con la espera de antes. |
| `scripts/google/connect.py` | La página guiada que crea la conexión de Google en el navegador y hace el OAuth en la misma pestaña. |
| `modules/ii/sidebarRight/calendar/AgendaWidget.qml` | La pestaña Agenda. |
| `modules/ii/sidebarRight/mail/MailWidget.qml` | La pestaña Mail. |
| `validate.qml` (raíz) | Banco de pruebas. Ver §8. |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `modules/common/Config.qml` | Bloque `services`: `google{}`, `apple{}` y `mail{}` con su lista `accounts`. |
| `modules/settings/ProfilePage.qml` | Sección **Cuentas**: Google, iCloud y Correo. Vive en Perfil y no en Servicios: son *tus* cuentas, no ajustes de la shell. |
| `modules/ii/sidebarRight/calendar/calendar_layout.js` | `dateKey` por casillero **y arreglo de un bug viejo** (§7). |
| `modules/ii/sidebarRight/calendar/CalendarDayButton.qml` | Puntitos de eventos + tooltip con la lista del día. |
| `modules/ii/sidebarRight/calendar/CalendarWidget.qml` | Pasa los eventos a cada día y mueve la ventana al cambiar de mes. |
| `services/Todo.qml` | `unifiedList` (local + Google + iCloud), `toggleDone(item)` / `removeItem(item)`, `remainingCount`. `list` sigue siendo sólo lo local y el archivo no cambió de formato. |
| `modules/ii/sidebarRight/todo/TaskList.qml` | Despacha por item en vez de por índice; marquita de origen. |
| `modules/ii/sidebarRight/todo/TodoWidget.qml` | Lee de `unifiedList`. |
| `modules/ii/sidebarRight/BottomWidgetGroup.qml` | Pestañas Agenda y Mail, condicionales y **al final** de la lista. |

Cada archivo modificado tiene su `.bak.20260826-*` al lado.

### Dónde vive cada secreto

| Dato | Dónde |
|---|---|
| Client ID de Google | `config.json` (no es secreto) |
| Client Secret de Google | **keyring**, bajo `google.client_secret` |
| Access / refresh token | **keyring**, bajo `google.*` |
| Apple ID | `config.json` (no es secreto) |
| Contraseña de app de iCloud | **keyring**, bajo `apple.appPassword` |
| Contraseñas de app del correo | **keyring**, bajo `mail.<id>.appPassword` |

Nada sensible toca `config.json`, que se copia y termina en cualquier backup.
Ninguna contraseña pasa por argumentos de proceso: van todas por variable de
entorno, porque lo que va en `argv` lo ve cualquiera que corra `ps`.

---

## 7. Un bug viejo que apareció en el camino

`calendar_layout.js` calculaba los días de cada mes con una regla de paridad
escrita a mano, y la regla estaba mal en dos bordes: para agosto daba que julio
tiene 30 días, y para julio daba que agosto tiene 30.

Efecto visible, que estaba ahí desde antes de todo esto: **en la grilla de agosto
faltaba el 31 de julio**, y toda la primera fila quedaba corrida un día. Con
eventos encima, cada uno hubiera caído en el casillero equivocado.

Reemplazado por `new Date(year, month, 0, 12).getDate()` — el día 0 del mes que
viene es el último de este. El mediodía no es capricho: en tu zona horaria la
medianoche del 6 de septiembre de 2026 no existe (cambio de hora) y
`new Date(2026, 8, 6)` devuelve el 5. Por eso todo lo que materializa un "día de
calendario" en este código lo hace a las 12:00.

Verificado con `validate.qml`: 6048 casilleros, doce años, cero fallas.

---

## 8. Cómo se prueba

```
qs -p ~/.config/quickshell/ii/validate.qml       # la shell entera: componentes + lógica
python3 ~/.config/quickshell/ii/scripts/apple/test_ical.py       # parser ICS y RRULE
python3 ~/.config/quickshell/ii/scripts/apple/test_caldav.py     # CalDAV contra un iCloud falso
python3 ~/.config/quickshell/ii/scripts/accounts/test_connect.py # conexión de iCloud/Gmail
python3 ~/.config/quickshell/ii/scripts/google/test_connect.py   # conexión guiada de Google
python3 ~/.config/quickshell/ii/scripts/mail/test_imap.py        # SSL vs STARTTLS y modo lectura
```

`validate.qml` instancia de verdad todos los componentes y además corre la
lógica: la grilla del calendario, el correo multicuenta (mezcla, orden, errores
por cuenta, migración de la config vieja) y la mezcla de proveedores del
calendario y del To Do. Toca `Config` y el keyring en memoria y restaura todo al
salir; el keyring nunca se escribe a disco.

Existe porque no había forma confiable de validar un `.qml` antes de guardarlo:
`qmlformat` falla en silencio con archivos que están perfectos, y `qs -c ii -n`
no anda con la shell ya corriendo. Es descartable: borralo cuando no lo quieras.

Los tests de Python corren sin red: `test_caldav.py` levanta un iCloud falso que
devuelve XML grabado, y `test_connect.py` maneja el servidor de conexión como lo
haría el navegador. Lo único que queda sin verificar hasta que conectes tu cuenta
es si el servidor real contesta igual que el falso.
