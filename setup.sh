#!/usr/bin/env bash
# ============================================================================
#  setup.sh — Instala Hyprland + Quickshell (ii) desde cero en Arch / CachyOS
#             y luego aplica los dotfiles de este repo.
#
#  Uso:   ./setup.sh              instalación completa
#         ./setup.sh --deps       solo paquetes
#         ./setup.sh --dots       solo la configuración (= install.sh)
#         ./setup.sh --venv       solo el entorno Python de la shell
#         ./setup.sh --upstream   clona el fork end4-pC como referencia
# ============================================================================
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# "illogical impulse" es el nombre del rice de end-4: sus metapaquetes
# illogical-impulse-* viven en este repo, en sdata/dist-arch/.
UPSTREAM="https://github.com/end-4/dots-hyprland.git"
# Fork del que porto features hacia mi shell ii (solo referencia, no se instala).
FORK="https://github.com/pctrade/end4-pC.git"
WORKDIR="${XDG_CACHE_HOME:-$HOME/.cache}/dots-setup"
VENV="$HOME/.local/state/quickshell/.venv"

c_ok()   { printf '\033[1;32m::\033[0m %s\n' "$*"; }
c_info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
c_err()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------- comprobaciones
preflight() {
  [ "$(id -u)" -eq 0 ] && { c_err "No lo corras como root. Usa tu usuario normal (pedirá sudo)."; exit 1; }
  command -v pacman >/dev/null || { c_err "Esto es para Arch/CachyOS (no encontré pacman)."; exit 1; }
  c_info "Actualizando el sistema primero"
  sudo pacman -Syu --noconfirm --needed base-devel git
}

# ---------------------------------------------------------------- helper AUR
ensure_aur() {
  if command -v yay >/dev/null; then AUR=yay; return; fi
  if command -v paru >/dev/null; then AUR=paru; return; fi
  c_info "Instalando yay (helper de AUR)"
  local d="$WORKDIR/yay-bin"
  rm -rf "$d"; mkdir -p "$WORKDIR"
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$d"
  ( cd "$d" && makepkg -si --noconfirm )
  AUR=yay
}

# ---------------------------------------------------------------- dependencias
install_deps() {
  ensure_aur
  c_info "Clonando los metapaquetes de end-4 (dots-hyprland)"
  mkdir -p "$WORKDIR"
  if [ -d "$WORKDIR/dots-hyprland/.git" ]; then
    git -C "$WORKDIR/dots-hyprland" pull --ff-only || true
  else
    git clone --depth 1 "$UPSTREAM" "$WORKDIR/dots-hyprland"
  fi

  local distdir="$WORKDIR/dots-hyprland/sdata/dist-arch"
  if [ ! -d "$distdir" ]; then
    c_err "No encontré $distdir — el upstream cambió de estructura."
    c_warn "Instala a mano lo listado en packages.txt y vuelve a correr: ./setup.sh --dots"
    return 1
  fi

  # Los metapaquetes illogical-impulse-* arrastran TODAS las dependencias
  # (hyprland, quickshell, qt6, fuentes, portales, etc.). Se construyen aquí
  # porque no están publicados en el AUR.
  c_info "Construyendo e instalando los metapaquetes illogical-impulse-*"
  local pkg
  for pkg in "$distdir"/illogical-impulse-*; do
    [ -f "$pkg/PKGBUILD" ] || continue
    case "$(basename "$pkg")" in
      illogical-impulse-microtex-git) continue ;;   # opcional (LaTeX en la shell)
    esac
    c_info "  → $(basename "$pkg")"
    ( cd "$pkg" && makepkg -si --noconfirm --needed ) \
      || c_warn "     falló $(basename "$pkg"); sigo con el resto"
  done

  c_info "Instalando los extras que uso además del set base"
  $AUR -S --needed --noconfirm \
    micro foot mpv btop fastfetch \
    visual-studio-code-bin spotify \
    qt6-avif-image-plugin || c_warn "algún extra no se pudo instalar"
}

# ---------------------------------------------------------------- venv python
setup_venv() {
  command -v uv >/dev/null || { c_warn "uv no está instalado; corre ./setup.sh --deps primero"; return 1; }
  c_info "Creando el entorno Python de la shell en $VENV"
  mkdir -p "$(dirname "$VENV")"
  uv venv --prompt .venv -p 3.12 "$VENV"

  local req="$WORKDIR/dots-hyprland/sdata/uv/requirements.txt"
  if [ -f "$req" ]; then
    # Lista fijada por el upstream: es la fuente de verdad.
    VIRTUAL_ENV="$VENV" uv pip install -r "$req" || c_warn "falló algún paquete de requirements.txt"
  else
    c_warn "No encontré requirements.txt del upstream; uso la lista de respaldo"
    VIRTUAL_ENV="$VENV" uv pip install \
      build pillow setuptools-scm wheel pywayland psutil kde-material-you-colors \
      materialyoucolor libsass material-color-utilities setproctitle click loguru \
      pycairo pygobject tqdm numpy opencv-contrib-python google-auth requests \
      || c_warn "algún paquete de Python falló"
  fi

  # Extras que usan mis widgets de correo/cuentas (no vienen en el upstream).
  VIRTUAL_ENV="$VENV" uv pip install dbus-python cryptography \
    || c_warn "no se pudieron instalar los extras de Python"
}

# ---------------------------------------------------------------- referencia
clone_upstream_ref() {
  local dst="$HOME/.config/quickshell/end4-pC"
  if [ -d "$dst/.git" ]; then
    c_info "El fork de referencia ya está en $dst"
  else
    c_info "Clonando el fork de referencia end4-pC en $dst"
    mkdir -p "$(dirname "$dst")"
    git clone "$FORK" "$dst" || c_warn "no se pudo clonar el fork de referencia"
  fi
}

# ---------------------------------------------------------------- servicios
enable_services() {
  c_info "Habilitando servicios"
  sudo systemctl enable --now bluetooth.service      2>/dev/null || true
  sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
  systemctl --user enable --now ydotool.service      2>/dev/null || c_warn "ydotool.service no disponible aún"
  systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
  systemctl --user enable --now gnome-keyring-daemon.socket 2>/dev/null || true
  # ydotool necesita acceso a /dev/uinput
  if ! groups | grep -qw input; then
    c_info "Agregando $USER al grupo input (para ydotool); requiere volver a iniciar sesión"
    sudo usermod -aG input "$USER" || true
  fi
}

# ---------------------------------------------------------------- dotfiles
install_dots() {
  c_info "Aplicando la configuración de este repo"
  "$SRC/install.sh"
}

# ---------------------------------------------------------------- main
case "${1:-all}" in
  --deps) preflight; install_deps ;;
  --venv) ensure_aur >/dev/null 2>&1 || true; setup_venv ;;
  --upstream) clone_upstream_ref ;;
  --dots) install_dots ;;
  all|"")
    preflight
    install_deps
    setup_venv
    enable_services
    install_dots
    clone_upstream_ref
    echo
    c_ok "Instalación terminada."
    echo "   1. Ajusta ~/.config/hypr/monitors.conf a tus pantallas."
    echo "   2. Cierra sesión y entra en Hyprland (o: hyprctl reload && qs -c ii)."
    echo "   3. Si ydotool no responde, reinicia para que aplique el grupo 'input'."
    ;;
  *) c_err "Opción desconocida: $1"; sed -n '2,12p' "$0"; exit 1 ;;
esac
