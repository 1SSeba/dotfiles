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

## Instalar en otro equipo

```bash
git clone <url-de-este-repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

El script hace backup de tu config actual en `~/.dotfiles-backup-<fecha>` antes de copiar.

Después:

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
