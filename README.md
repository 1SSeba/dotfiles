# dotfiles

Configuración personal de **Hyprland + Quickshell (`ii`)** en CachyOS/Arch.

## Qué incluye

| Ruta | Qué es |
|---|---|
| `.config/hypr` | Hyprland, hypridle, hyprlock, keybinds, reglas, scripts |
| `.config/quickshell/ii` | La shell `ii` (barra, sidebars, launcher, lock, widgets) |
| `.config/illogical-impulse` | `config.json` de la shell (opciones de usuario) |
| `.config/fish`, `.zshrc`, `.bashrc` | Shells + starship |
| `.config/kitty`, `foot`, `fuzzel`, `wlogout` | Terminales y menús |
| `.config/matugen`, `Kvantum`, `gtk-3.0/4.0`, `kde-material-you-colors` | Temas y colores |
| `.config/cava`, `mpv`, `micro` | Utilidades |

También incluye, fuera de `~/.config`:

- `local/lib/qs-webengine-shim/` — shim en C++ que se carga con `LD_PRELOAD` al lanzar
  la shell (habilita `WebEngineView` dentro de quickshell). `install.sh` lo compila.
- `state-seed/` — colores por defecto para `~/.local/state/quickshell/user/generated`,
  para que la shell tenga tema en el primer arranque.

No incluye: `quickshell/end4-pC` (es el upstream de end-4, se clona aparte), backups `*.bak.*`,
caches y estado generado en `~/.local/state/quickshell`.

## Instalar en un equipo nuevo (Arch / CachyOS)

Desde una instalación limpia, esto deja el sistema completo: paquetes, Hyprland,
Quickshell, entorno Python, servicios y la configuración.

```bash
git clone https://github.com/1SSeba/dotfiles.git ~/dotfiles
cd ~/dotfiles
./setup.sh
```

Luego cierra sesión y entra en Hyprland.

### Por partes

| Comando | Qué hace |
|---|---|
| `./setup.sh` | Todo: paquetes + venv + servicios + configuración |
| `./setup.sh --deps` | Solo paquetes (yay + metapaquetes `illogical-impulse-*` + extras) |
| `./setup.sh --venv` | Solo el entorno Python de la shell (`~/.local/state/quickshell/.venv`) |
| `./setup.sh --upstream` | Clona el fork de referencia `end4-pC` en `~/.config/quickshell/` |
| `./setup.sh --dots` | Solo la configuración (igual que `./install.sh`) |
| `./install.sh` | Copia la config a `~/.config` con backup previo |
| `./setup.sh --fonts` | Solo la fuente Google Sans Flex (se clona, no viene empaquetada) |
| `./sync.sh` | Vuelca la config viva de `~/.config` a este repo |
| `./doctor.sh` | Diagnostica por qué no carga la shell (no modifica nada) |

**De dónde salen las dependencias:** "illogical impulse" es el nombre del rice de end-4,
así que `setup.sh` clona `end-4/dots-hyprland` y construye sus metapaquetes
`illogical-impulse-*` desde `sdata/dist-arch/` (no están publicados en el AUR).
Ellos arrastran hyprland, quickshell, Qt6, portales, fuentes y temas. El entorno
Python sale del `sdata/uv/requirements.txt` fijado por el upstream.
En `packages.txt` está la lista completa por si prefieres instalar a mano.

`install.sh` respalda tu config actual en `~/.dotfiles-backup-<fecha>` antes de copiar.

Si solo quieres recargar sin reiniciar sesión:

```bash
hyprctl reload
qs -c ii      # o el alias `q`
```

## Notas por equipo

- `.config/hypr/monitors.conf` es específico de cada máquina: ajústalo tras instalar.
- El upstream de referencia, si lo quieres tener al lado:
  `git clone https://github.com/end-4/dots-hyprland ~/.config/quickshell/end4-pC`
- Dependencias: hyprland, quickshell, matugen, fuzzel, kitty, starship, eza, cava, wlogout.

## Actualizar el repo desde la máquina en uso

```bash
cd ~/dotfiles && ./sync.sh && git add -A && git commit -m "update" && git push
```

## Si la shell no carga

```bash
./doctor.sh
```

Revisa binarios, los `source` de `hyprland.conf`, el shim de `LD_PRELOAD`, los colores
generados, el venv, las fuentes y el wallpaper, e intenta cargar la config de quickshell.

Causas típicas en un equipo nuevo:

| Síntoma | Causa | Arreglo |
|---|---|---|
| Hyprland arranca pero no hay barra ni widgets | falta `qs` o el shim de `LD_PRELOAD` | `./setup.sh --deps` y `./install.sh` |
| Barra sin colores / iconos cuadrados | faltan los colores generados o las fuentes | `./install.sh` y `./setup.sh --fonts` |
| El fondo no aparece | `wallpaperPath` apunta a la otra máquina | cámbialo en `~/.config/illogical-impulse/config.json` |
| Banner rojo de error de config | falta algún archivo que `hyprland.conf` hace `source` | `./doctor.sh` te dice cuál |
