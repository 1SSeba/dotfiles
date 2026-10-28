#!/usr/bin/env python3
"""
Copia las cookies de un navegador Chromium (Edge, Chrome, Brave, Vivaldi...) al
perfil de QtWebEngine que usa una pestaña del sidebar social.

Por qué existe este adefesio
----------------------------
QtWebEngine NO expone QWebEngineCookieStore a QML: desde el .qml no hay ninguna
forma de inyectar una cookie en un WebEngineView. Y por JavaScript tampoco, porque
las cookies de sesión que importan (sessionid de Instagram, auth_token de X) son
HttpOnly y document.cookie no las puede escribir.

Así que la única vía es offline: descifrar el SQLite del navegador y escribir a
mano en el SQLite del perfil de QtWebEngine, con la shell cerrada. Eso es lo que
hace esto.

Cómo cifra Chromium en Linux
----------------------------
El valor va en `encrypted_value` con un prefijo de 3 bytes:
  - v10: clave derivada de la contraseña fija "peanuts" (backend `basic`, el que
         se usa cuando no hay keyring disponible).
  - v11: clave derivada de una contraseña guardada en la keyring del sistema
         (gnome-keyring/kwallet), bajo el schema de libsecret de Chromium.
En los dos casos: PBKDF2-HMAC-SHA1(pass, b"saltysalt", 1 iter, 16 bytes), luego
AES-128-CBC con IV de 16 espacios.

Desde Chromium 130 el texto plano lleva además un prefijo de 32 bytes con el
SHA-256 del dominio, para atar la cookie a su host. Se detecta y se maneja solo.

Uso
---
    import_browser_cookies.py --check
    import_browser_cookies.py --profile social-instagram --domain instagram.com
    import_browser_cookies.py --profile social-instagram --domain instagram.com --apply

Sin --apply no escribe nada: te dice qué haría.
"""

import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
    from cryptography.hazmat.primitives import hashes
except ImportError:
    sys.exit("Falta python-cryptography. Instalalo con: sudo pacman -S python-cryptography")

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state"))
SOCIAL_PROFILES = STATE / "quickshell/user/social"

SALT = b"saltysalt"
IV = b" " * 16

# (carpeta de config, valor del atributo `application` en la keyring)
BROWSERS = {
    "microsoft-edge": ("microsoft-edge", "chromium"),
    "chromium": ("chromium", "chromium"),
    "google-chrome": ("google-chrome", "chrome"),
    "brave": ("BraveSoftware/Brave-Browser", "brave"),
    "vivaldi": ("vivaldi", "vivaldi"),
}


# --------------------------------------------------------------------------- #
# Cripto
# --------------------------------------------------------------------------- #

def derive_key(password: bytes) -> bytes:
    kdf = PBKDF2HMAC(algorithm=hashes.SHA1(), length=16, salt=SALT, iterations=1)
    return kdf.derive(password)


def aes_decrypt(key: bytes, blob: bytes) -> bytes:
    dec = Cipher(algorithms.AES(key), modes.CBC(IV)).decryptor()
    out = dec.update(blob) + dec.finalize()
    if out:  # quitar padding PKCS7
        pad = out[-1]
        if 1 <= pad <= 16:
            out = out[:-pad]
    return out


def keyring_password(app: str) -> bytes | None:
    """La contraseña de 'Safe Storage' del navegador, si está en la keyring."""
    try:
        r = subprocess.run(
            ["secret-tool", "lookup", "application", app],
            capture_output=True, timeout=15,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 and r.stdout else None


def decrypt_value(blob: bytes, keys: dict, host: str) -> str | None:
    """Descifra un encrypted_value. `keys` mapea prefijo (v10/v11) -> clave."""
    if not blob:
        return None
    prefix, body = blob[:3], blob[3:]
    key = keys.get(prefix.decode("ascii", "replace"))
    if key is None:
        return None
    try:
        plain = aes_decrypt(key, body)
    except Exception:
        return None
    # Chromium >=130 antepone sha256(host) al texto plano.
    if len(plain) >= 32 and plain[:32] == hashlib.sha256(host.encode()).digest():
        plain = plain[32:]
    try:
        return plain.decode("utf-8")
    except UnicodeDecodeError:
        return None


# --------------------------------------------------------------------------- #
# Bases
# --------------------------------------------------------------------------- #

def open_ro(path: Path) -> sqlite3.Connection:
    """Abre una copia: la original puede estar bloqueada por el navegador abierto."""
    tmp = Path(tempfile.mkdtemp(prefix="cookieimport-")) / "Cookies"
    shutil.copy2(path, tmp)
    for suffix in ("-wal", "-journal"):
        side = path.with_name(path.name + suffix)
        if side.exists():
            shutil.copy2(side, tmp.with_name(tmp.name + suffix))
    return sqlite3.connect(tmp)


def columns(con: sqlite3.Connection, table: str) -> list[str]:
    return [r[1] for r in con.execute(f"PRAGMA table_info({table})")]


def browser_cookie_db(browser: str, browser_profile: str) -> Path | None:
    folder = BROWSERS[browser][0]
    base = HOME / ".config" / folder / browser_profile
    for candidate in (base / "Network" / "Cookies", base / "Cookies"):
        if candidate.exists():
            return candidate
    return None


# Nota sobre el destino: QtWebEngine NO cifra las cookies en disco. El cifrado
# (encrypted_value con prefijo v10/v11 y clave en la keyring) lo agrega la capa
# de navegador de Chrome/Edge, que QtWebEngine no implementa: guarda todo en la
# columna `value` en texto plano, con `encrypted_value` vacío. Verificado en este
# sistema (schema v24). Por eso al importar sólo desciframos lo de Edge y
# escribimos el texto plano tal cual; no hay nada que re-cifrar para el destino.


# --------------------------------------------------------------------------- #
# Diagnóstico
# --------------------------------------------------------------------------- #

def cmd_check() -> int:
    print("=== Perfiles de QtWebEngine del sidebar social ===")
    print(f"Carpeta base: {SOCIAL_PROFILES}")
    if not SOCIAL_PROFILES.exists():
        print("  NO EXISTE.")
        print("  => El perfil no está persistiendo. Abrí una pestaña social en el")
        print("     sidebar al menos una vez y volvé a correr esto. Si sigue sin")
        print("     aparecer, el problema es la persistencia, no las cookies.")
    else:
        found = False
        for d in sorted(SOCIAL_PROFILES.iterdir()):
            if not d.is_dir():
                continue
            found = True
            db = d / "Cookies"
            if db.exists():
                try:
                    con = open_ro(db)
                    n = list(con.execute("SELECT count(*) FROM cookies"))[0][0]
                    hosts = [r[0] for r in con.execute(
                        "SELECT DISTINCT host_key FROM cookies ORDER BY host_key LIMIT 8")]
                    sample = list(con.execute(
                        "SELECT encrypted_value FROM cookies "
                        "WHERE length(encrypted_value) > 3 LIMIT 1"))
                    scheme = sample[0][0][:3].decode("ascii", "replace") if sample else "sin datos"
                    print(f"  {d.name}: {n} cookies, cifrado={scheme}, hosts={hosts}")
                except Exception as e:
                    print(f"  {d.name}: no se pudo leer Cookies ({e})")
            else:
                print(f"  {d.name}: carpeta creada pero SIN base Cookies todavía")
        if not found:
            print("  Carpeta vacía: ninguna pestaña social se abrió aún.")

    print()
    print("=== Navegadores con base de cookies ===")
    for name in BROWSERS:
        for prof in ("Default", "Profile 1"):
            db = browser_cookie_db(name, prof)
            if db:
                try:
                    con = open_ro(db)
                    n = list(con.execute("SELECT count(*) FROM cookies"))[0][0]
                    print(f"  {name} / {prof}: {n} cookies  ({db})")
                except Exception as e:
                    print(f"  {name} / {prof}: no se pudo leer ({e})")

    print()
    print("=== Claves de cifrado disponibles en la keyring ===")
    for name, (_, app) in BROWSERS.items():
        pw = keyring_password(app)
        print(f"  {name}: atributo application={app!r} -> "
              f"{'ENCONTRADA' if pw else 'no encontrada'}")

    print()
    print("=== Shell ===")
    r = subprocess.run(["pgrep", "-c", "quickshell"], capture_output=True, text=True)
    running = r.stdout.strip() not in ("", "0")
    print(f"  quickshell corriendo: {'SI - cerrala antes de --apply' if running else 'no'}")
    return 0


# --------------------------------------------------------------------------- #
# Importación
# --------------------------------------------------------------------------- #

def cmd_import(args) -> int:
    target_dir = SOCIAL_PROFILES / args.profile
    target_db = target_dir / "Cookies"
    if not target_db.exists():
        print(f"No existe {target_db}", file=sys.stderr)
        print("Abrí esa pestaña en el sidebar una vez para que se cree el perfil, "
              "cerrá la shell, y volvé a intentar.", file=sys.stderr)
        return 1

    if args.apply:
        r = subprocess.run(["pgrep", "-c", "quickshell"], capture_output=True, text=True)
        if r.stdout.strip() not in ("", "0"):
            print("quickshell está corriendo. Cerralo antes de escribir en el perfil "
                  "o vas a corromper la base.", file=sys.stderr)
            return 1

    src_db = browser_cookie_db(args.browser, args.browser_profile)
    if src_db is None:
        print(f"No encontré la base de cookies de {args.browser} / {args.browser_profile}",
              file=sys.stderr)
        return 1

    # Claves para DESCIFRAR lo del navegador
    app = BROWSERS[args.browser][1]
    src_keys = {"v10": derive_key(b"peanuts")}
    pw = keyring_password(app)
    if pw:
        src_keys["v11"] = derive_key(pw)
    else:
        print(f"[aviso] no hay clave en la keyring para application={app!r}: "
              f"las cookies v11 no se van a poder descifrar")

    src = open_ro(src_db)
    src_cols = columns(src, "cookies")

    domains = [d.lstrip(".") for d in args.domain]
    where = " OR ".join(["host_key = ? OR host_key = ? OR host_key LIKE ?"] * len(domains))
    params: list[str] = []
    for d in domains:
        params += [d, "." + d, "%." + d]

    rows = [dict(zip(src_cols, r))
            for r in src.execute(f"SELECT * FROM cookies WHERE {where}", params)]
    if not rows:
        print(f"No hay cookies para {domains} en {args.browser}.")
        return 1

    # QtWebEngine (verificado en este sistema, schema v24) guarda las cookies en
    # TEXTO PLANO: columna `value` llena, `encrypted_value` vacío. Así que sólo
    # desciframos lo de Edge y escribimos el texto plano tal cual, sin re-cifrar.
    tgt = sqlite3.connect(target_db)
    tgt_info = list(tgt.execute("PRAGMA table_info(cookies)"))  # cid,name,type,notnull,dflt,pk
    tgt_cols = [c[1] for c in tgt_info]

    def column_default(col):
        """Valor por defecto para una columna del destino que el origen no trae."""
        _, _, ctype, _, dflt, _ = col
        if dflt is not None:
            return dflt
        return b"" if ctype.upper() == "BLOB" else (0 if ctype.upper() == "INTEGER" else "")

    prepared, failed = [], 0
    for row in rows:
        host = row.get("host_key", "")
        plain = decrypt_value(row.get("encrypted_value") or b"", src_keys, host)
        if plain is None:
            plain = row.get("value") or ""      # algunas cookies ya vienen en claro
            if not plain:
                failed += 1
                continue
        # Fila completa para el destino: cada columna sale del origen si está,
        # y si no del default del schema (así no se rompe en las NOT NULL nuevas
        # como top_frame_site_key / has_cross_site_ancestor de la v24).
        out = {}
        for col in tgt_info:
            cname = col[1]
            out[cname] = row[cname] if cname in row else column_default(col)
        out["value"] = plain          # texto plano, como guarda QtWebEngine
        out["encrypted_value"] = b""  # vacío: no va cifrado
        prepared.append(out)

    print(f"{len(prepared)} cookies listas para copiar"
          + (f", {failed} no se pudieron descifrar" if failed else ""))
    interesting = {"sessionid", "auth_token", "ct0", "ds_user_id", "li_at", "c_user", "xs"}
    for r in prepared[:60]:
        mark = "  <- sesión" if r.get("name") in interesting else ""
        print(f"  {r.get('host_key'):40} {r.get('name')}{mark}")
    if len(prepared) > 60:
        print(f"  ... y {len(prepared) - 60} más")
    got = {r.get("name") for r in prepared}
    if not (got & interesting):
        print("\n[ojo] No apareció ninguna cookie de sesión conocida "
              "(sessionid, auth_token, ct0...). Puede que en Edge no estés logueado "
              "en ese sitio, o que la sesión no viva en cookies.")

    if not args.apply:
        print("\nEnsayo nomás. Volvé a correrlo con --apply para escribir de verdad.")
        return 0

    backup = target_db.with_name(f"Cookies.bak-{time.strftime('%Y%m%d-%H%M%S')}")
    shutil.copy2(target_db, backup)
    print(f"Backup: {backup}")

    placeholders = ",".join("?" * len(tgt_cols))
    collist = ",".join(f'"{c}"' for c in tgt_cols)
    written = 0
    for r in prepared:
        try:
            tgt.execute(
                f"INSERT OR REPLACE INTO cookies ({collist}) VALUES ({placeholders})",
                [r.get(c) for c in tgt_cols],
            )
            written += 1
        except sqlite3.Error as e:
            print(f"  [fallo] {r.get('host_key')} {r.get('name')}: {e}")
    tgt.commit()
    print(f"Escritas {written} cookies en {target_db}")
    print("Abrí el sidebar. Si el sitio te sigue pidiendo login, es que ató la sesión "
          "al fingerprint del navegador y no hay nada que hacer por esta vía.")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--check", action="store_true",
                   help="diagnostica perfiles, navegadores y claves; no toca nada")
    p.add_argument("--profile", help="perfil destino, p.ej. social-instagram")
    p.add_argument("--domain", action="append", default=[],
                   help="dominio a copiar (repetible), p.ej. instagram.com")
    p.add_argument("--browser", default="microsoft-edge", choices=sorted(BROWSERS))
    p.add_argument("--browser-profile", default="Default")
    p.add_argument("--apply", action="store_true",
                   help="escribir de verdad (sin esto es un ensayo)")
    args = p.parse_args()

    if args.check:
        return cmd_check()
    if not args.profile or not args.domain:
        p.error("hacen falta --profile y --domain (o usá --check)")
    return cmd_import(args)


if __name__ == "__main__":
    sys.exit(main())
