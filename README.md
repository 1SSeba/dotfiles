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
| `./sync.sh` | Vuelca la config viva de `~/.config` a este repo |

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
