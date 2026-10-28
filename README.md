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

### Secciones

`setup.sh` va por secciones numeradas, en un orden que importa: primero los repos
oficiales, luego el AUR (porque `makepkg` no resuelve dependencias del AUR), y solo
entonces los metapaquetes.

```
 0  Preparación del sistema            6  Fuentes
 1  Herramientas de compilación y AUR  7  Extras opcionales
 2  Dependencias de repos oficiales    8  Servicios
 3  Dependencias del AUR               9  Configuración (dotfiles + shim)
 4  Metapaquetes illogical-impulse-*  10  Fork de referencia
 5  Entorno Python (uv)               11  Verificación final
```

Pide la contraseña de sudo **una sola vez** al principio y mantiene el ticket vivo,
así que ni pacman ni yay ni makepkg la vuelven a pedir a mitad de la instalación.

| Comando | Qué hace |
|---|---|
| `./setup.sh` | Todo, en orden |
| `./setup.sh --list` | Lista las secciones |
| `./setup.sh --from 5` | Reanuda desde la sección 5 (si algo falló) |
| `./setup.sh --only 4` | Ejecuta solo una sección (acepta `2,3,4`) |
| `./setup.sh --skip-extras` | Omite vscode/spotify y demás |
| `./setup.sh --yes` | Sin confirmación inicial |
| `./setup.sh --deps` | Atajo de `--only 2,3,4` |
| `./setup.sh --venv` / `--fonts` / `--dots` / `--upstream` / `--check` | Atajos de 5 / 6 / 9 / 10 / 11 |
| `./install.sh` | Solo configuración: copia con backup, compila el shim, siembra colores |
| `./sync.sh` | Vuelca la config viva de `~/.config` a este repo |
| `./doctor.sh` | Diagnostica por qué no carga la shell (no modifica nada) |

Muestra una barra de progreso por sección y por paquete, y **la salida de pacman,
yay y makepkg va en vivo a la pantalla** además del log. Compilar quickshell tarda
varios minutos: mientras se vea salida, está trabajando.

Si un paquete falla, el script no se detiene: reintenta el lote uno por uno, sigue
con el resto y al final lista lo que quedó pendiente. Todo queda registrado en
`~/.cache/dots-setup/setup-<fecha>.log`.

**De dónde salen las dependencias:** "illogical impulse" es el nombre del rice de end-4,
así que `setup.sh` clona `end-4/dots-hyprland` y construye sus metapaquetes
`illogical-impulse-*` desde `sdata/dist-arch/` (no están publicados en el AUR).
Son 99 paquetes de repos oficiales + 11 del AUR + 13 metapaquetes. El entorno Python
sale del `sdata/uv/requirements.txt` fijado por el upstream. La lista completa,
ordenada por sección, está en `packages.txt`.

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
| `yay` parece colgado instalando | estaba esperando una respuesta invisible | ya no: la salida va en vivo y yay corre con `--answer*=None` |
