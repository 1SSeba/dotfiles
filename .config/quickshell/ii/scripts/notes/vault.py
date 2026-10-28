#!/usr/bin/env python3
"""
Las notas del widget del escritorio, guardadas como archivos .md en una vault de
Obsidian: una nota, un archivo. Así se leen, se editan y se ordenan igual desde
Obsidian, y lo que se cambie allá aparece en el widget (services/Notes.qml relee
seguido).

    vault.py list    <vault>                  -> las notas y las carpetas
    vault.py save    <vault> <id|"">          -> crea (id vacío) o reescribe una nota
    vault.py trash   <vault> <id>             -> la manda a la papelera de Obsidian
    vault.py move    <vault> <id> <carpeta>   -> la cambia de carpeta ("" = raíz)
    vault.py pin     <vault> <id> <0|1>       -> la fija o la desfija
    vault.py mkdir   <vault> <carpeta>        -> crea una carpeta
    vault.py rmdir   <vault> <carpeta>        -> manda la carpeta entera a la papelera

El id de una nota es su ruta dentro de la vault ("Trabajo/Comprar pan.md"). El
nombre del archivo es el título de la nota; sin título, sale de la primera línea
del texto. Si el título cambia, el archivo se renombra, como haría Obsidian.

Organizar es usar carpetas de verdad, así Obsidian ve lo mismo que el widget:
archivar es mover a la carpeta "Archivo". Fijar, en cambio, es una propiedad
(`pinned: true` en el frontmatter), porque una nota fijada sigue perteneciendo a
su carpeta. El resto del frontmatter (tags, lo que agregues en Obsidian) se
conserva tal cual.

Los textos entran por variables de entorno y no como argumentos (lo que va en
argv lo ve cualquiera que corra `ps`): NOTE_TITLE, NOTE_CONTENT y, al crear,
NOTE_FOLDER y NOTE_PINNED.

Borrar no borra: mueve a <vault>/.trash, la papelera propia de Obsidian (la de
"Mover a la papelera de Obsidian"), así que se puede recuperar.

La primera vez crea la vault (la carpeta y su .obsidian/) y la registra en
~/.config/obsidian/obsidian.json para que aparezca en el selector de vaults.

Salida, siempre un JSON por stdout, con todo ya actualizado:
    {"ok": true, "id": "...", "notes": [{"id", "folder", "title", "content",
     "pinned", "modified"}], "folders": ["Archivo", "Trabajo", ...]}
    {"ok": false, "error": "texto"}
"""
import json
import os
import re
import secrets
import sys
import time

OBSIDIAN_CONFIG = os.path.expanduser("~/.config/obsidian/obsidian.json")
# Lo que Obsidian (o el sistema de archivos) no acepta en un nombre
FORBIDDEN = re.compile(r'[\\/:*?"<>|#^\[\]\x00-\x1f]')
MAX_NAME = 60
PINNED_LINE = re.compile(r"^pinned\s*:", re.IGNORECASE)
PINNED_TRUE = re.compile(r"^pinned\s*:\s*(true|yes|1)\s*$", re.IGNORECASE)


# ---------------------------------------------------------------- vault --

def register_vault(vault):
    """Agrega la vault a obsidian.json si todavía no está. Sin esto existe la
    carpeta pero Obsidian no la ofrece hasta que la abras a mano."""
    try:
        with open(OBSIDIAN_CONFIG, encoding="utf-8") as f:
            config = json.load(f)
    except FileNotFoundError:
        return  # Obsidian nunca se abrió en esta máquina: no hay a quién avisarle
    except (OSError, ValueError):
        return  # ilegible: mejor no tocarlo que pisarlo
    vaults = config.setdefault("vaults", {})
    if any(os.path.realpath(v.get("path", "")) == os.path.realpath(vault) for v in vaults.values()):
        return
    vaults[secrets.token_hex(8)] = {"path": vault, "ts": int(time.time() * 1000)}
    tmp = OBSIDIAN_CONFIG + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(config, f)
    os.replace(tmp, OBSIDIAN_CONFIG)


def ensure_vault(vault):
    os.makedirs(os.path.join(vault, ".obsidian"), exist_ok=True)
    register_vault(vault)


# ---------------------------------------------------------- frontmatter --

def split_frontmatter(text):
    """(renglones del frontmatter, cuerpo). Sin frontmatter: ([], texto)."""
    if text.startswith("---\n"):
        end = text.find("\n---", 4)
        if end != -1:
            rest = text[end + 4:]
            if rest.startswith("\n"):
                rest = rest[1:]
            return text[4:end].split("\n"), rest
    return [], text


def join_frontmatter(lines, body):
    lines = [line for line in lines if line.strip()]
    if not lines:
        return body
    return "---\n" + "\n".join(lines) + "\n---\n" + body


def with_pinned(lines, pinned):
    lines = [line for line in lines if not PINNED_LINE.match(line)]
    return lines + ["pinned: true"] if pinned else lines


# ---------------------------------------------------------------- rutas --

def clean_name(text):
    # Un "# Título" de markdown no lleva el # al nombre
    text = re.sub(r"^#+\s*", "", text.strip())
    return FORBIDDEN.sub("", text).strip(" .")[:MAX_NAME].strip(" .")


def name_for(title, content):
    """Nombre (sin .md): el título, o si no hay, la primera línea con algo."""
    first = next((line for line in content.splitlines() if line.strip()), "")
    return clean_name(title) or clean_name(first) or "Nota"


def free_name(folder, base, keep=None):
    """base.md, o base 2.md, base 3.md... el primero libre (keep cuenta como libre)."""
    candidate = f"{base}.md"
    n = 2
    while os.path.exists(os.path.join(folder, candidate)) and candidate != keep:
        candidate = f"{base} {n}.md"
        n += 1
    return candidate


def safe_rel(path, note=False):
    """Una ruta que viene de afuera: relativa, sin '..' ni carpetas ocultas,
    para que nunca se salga de la vault ni toque .obsidian o .trash."""
    parts = [p for p in path.split("/") if p]
    if any(p in (".", "..") or p.startswith(".") for p in parts):
        raise ValueError(f"ruta inválida: {path!r}")
    if note and (not parts or not parts[-1].endswith(".md")):
        raise ValueError(f"id de nota inválido: {path!r}")
    return "/".join(parts)


def folder_of(note_id):
    return note_id.rsplit("/", 1)[0] if "/" in note_id else ""


def join(folder, name):
    return f"{folder}/{name}" if folder else name


# --------------------------------------------------------------- lectura --

def read(vault, note_id):
    with open(os.path.join(vault, note_id), encoding="utf-8", errors="replace") as f:
        return f.read()


def list_all(vault):
    notes, folders = [], []
    for current, dirs, files in os.walk(vault):
        # Nada de .obsidian, .trash ni otras carpetas ocultas
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        rel = os.path.relpath(current, vault)
        rel = "" if rel == "." else rel.replace(os.sep, "/")
        if rel:
            folders.append(rel)
        for name in files:
            if not name.endswith(".md") or name.startswith("."):
                continue
            note_id = join(rel, name)
            meta, body = split_frontmatter(read(vault, note_id))
            notes.append({
                "id": note_id,
                "folder": rel,
                "title": name[:-3],
                "content": body,
                "pinned": any(PINNED_TRUE.match(line) for line in meta),
                "modified": int(os.path.getmtime(os.path.join(vault, note_id)) * 1000),
            })
    return notes, folders


# -------------------------------------------------------------- escritura --

def write(vault, note_id, text):
    path = os.path.join(vault, note_id)
    tmp = os.path.join(os.path.dirname(path), "." + os.path.basename(path) + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def save(vault, note_id, title, content, folder="", pinned=False):
    if note_id:
        note_id = safe_rel(note_id, note=True)
        folder = folder_of(note_id)
        old_path = os.path.join(vault, note_id)
        meta = split_frontmatter(read(vault, note_id))[0] if os.path.exists(old_path) else []
    else:
        folder = safe_rel(folder)
        meta = with_pinned([], pinned)
    folder_abs = os.path.join(vault, folder)
    os.makedirs(folder_abs, exist_ok=True)
    keep = note_id.rsplit("/", 1)[-1] if note_id else None
    target = join(folder, free_name(folder_abs, name_for(title, content), keep=keep))
    if note_id and target != note_id and os.path.exists(os.path.join(vault, note_id)):
        os.replace(os.path.join(vault, note_id), os.path.join(vault, target))
    write(vault, target, join_frontmatter(meta, content))
    return target


def trash(vault, rel):
    rel = safe_rel(rel)
    src = os.path.join(vault, rel)
    if not rel or not os.path.exists(src):
        return
    trash_dir = os.path.join(vault, ".trash")
    os.makedirs(trash_dir, exist_ok=True)
    name = rel.rsplit("/", 1)[-1]
    if os.path.isdir(src):
        dest, n = name, 2
        while os.path.exists(os.path.join(trash_dir, dest)):
            dest, n = f"{name} {n}", n + 1
    else:
        dest = free_name(trash_dir, name[:-3])
    os.replace(src, os.path.join(trash_dir, dest))


def move(vault, note_id, folder):
    note_id, folder = safe_rel(note_id, note=True), safe_rel(folder)
    if folder_of(note_id) == folder:
        return note_id
    folder_abs = os.path.join(vault, folder)
    os.makedirs(folder_abs, exist_ok=True)
    target = join(folder, free_name(folder_abs, note_id.rsplit("/", 1)[-1][:-3]))
    os.replace(os.path.join(vault, note_id), os.path.join(vault, target))
    return target


def pin(vault, note_id, pinned):
    note_id = safe_rel(note_id, note=True)
    meta, body = split_frontmatter(read(vault, note_id))
    write(vault, note_id, join_frontmatter(with_pinned(meta, pinned), body))
    return note_id


def mkdir(vault, name):
    # Un solo nivel desde el widget; las anidadas se crean en Obsidian
    clean = clean_name(name)
    if not clean:
        raise ValueError("nombre de carpeta vacío")
    os.makedirs(os.path.join(vault, clean), exist_ok=True)
    return clean


# ----------------------------------------------------------------- main --

def main():
    if len(sys.argv) < 3:
        raise ValueError("uso: vault.py list|save|trash|move|pin|mkdir|rmdir <vault> ...")
    command, vault = sys.argv[1], os.path.expanduser(sys.argv[2])
    arg = lambda i: sys.argv[i] if len(sys.argv) > i else ""  # noqa: E731
    env = os.environ.get
    ensure_vault(vault)
    result = {"ok": True}
    if command == "save":
        result["id"] = save(vault, arg(3), env("NOTE_TITLE", ""), env("NOTE_CONTENT", ""),
                            env("NOTE_FOLDER", ""), env("NOTE_PINNED", "") == "1")
    elif command == "trash":
        trash(vault, safe_rel(arg(3), note=True))
    elif command == "move":
        result["id"] = move(vault, arg(3), arg(4))
    elif command == "pin":
        result["id"] = pin(vault, arg(3), arg(4) == "1")
    elif command == "mkdir":
        result["id"] = mkdir(vault, arg(3))
    elif command == "rmdir":
        if not safe_rel(arg(3)):
            raise ValueError("no se puede borrar la raíz de la vault")
        trash(vault, arg(3))
    elif command != "list":
        raise ValueError(f"comando desconocido: {command}")
    result["notes"], result["folders"] = list_all(vault)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001 — cualquier falla sale como JSON, no como traceback
        print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
        sys.exit(1)
