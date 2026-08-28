#!/usr/bin/env bash
# =============================================================================
#  setup.sh — Instalación completa de Hyprland + Quickshell (ii) en Arch/CachyOS
#
#  Secciones (se ejecutan en este orden; el orden importa):
#     0  Preparación del sistema        6  Fuentes
#     1  Herramientas de compilación    7  Extras opcionales
#     2  Dependencias de repos          8  Servicios
#     3  Dependencias del AUR           9  Configuración (dotfiles + shim)
#     4  Metapaquetes illogical-*      10  Fork de referencia
#     5  Entorno Python (uv)           11  Verificación final
#
#  Uso:
#     ./setup.sh                 todo, en orden
#     ./setup.sh --list          muestra las secciones
#     ./setup.sh --only 4        ejecuta solo la sección 4
#     ./setup.sh --from 5        reanuda desde la sección 5 (útil si algo falló)
#     ./setup.sh --skip-extras   omite la sección 7
#     ./setup.sh --yes           sin confirmación inicial
#
#  Atajos: --deps (2,3,4)  --venv (5)  --fonts (6)  --dots (9)  --upstream (10)
#
#  Registro completo en ~/.cache/dots-setup/setup-<fecha>.log
# =============================================================================
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${XDG_CACHE_HOME:-$HOME/.cache}/dots-setup"
LOG="$WORKDIR/setup-$(date +%Y%m%d-%H%M%S).log"
VENV="$HOME/.local/state/quickshell/.venv"

UPSTREAM="https://github.com/end-4/dots-hyprland.git"   # "illogical impulse" es este repo
FORK="https://github.com/pctrade/end4-pC.git"           # fork del que porto features
FONT_REPO="https://github.com/end-4/google-sans-flex"   # fuente de la UI, sin empaquetar

FROM=0; ONLY=""; SKIP_EXTRAS=0; ASSUME_YES=0
FAILED=()

# -----------------------------------------------------------------------------
#  Utilidades
# -----------------------------------------------------------------------------
# Barra de progreso: barra <hechos> <total> <etiqueta>
barra() {
  local cur="$1" tot="$2" etiqueta="${3:-}"
  local ancho=28
  local pct=$(( tot > 0 ? cur * 100 / tot : 0 ))
  local llenos=$(( tot > 0 ? cur * ancho / tot : 0 ))
  local vacios=$(( ancho - llenos ))
  local barraTxt=''
  local i
  for (( i = 0; i < llenos; i++ )); do barraTxt+='█'; done
  for (( i = 0; i < vacios; i++ )); do barraTxt+='░'; done
  printf '\033[1;36m[\033[0m%s\033[1;36m]\033[0m %3d%%  %s/%s  %s\n' \
    "$barraTxt" "$pct" "$cur" "$tot" "$etiqueta"
}

# Cabecera de sección, con la barra del avance general.
SEC_ACTUAL=0
SEC_TOTAL=12
b() {
  printf '\n\033[1;36m━━ %s ━━\033[0m\n' "$*"
  barra "$SEC_ACTUAL" "$SEC_TOTAL" "sección $SEC_ACTUAL de $SEC_TOTAL"
}
info()   { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()     { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn()   { printf '\033[1;33m !!\033[0m %s\n' "$*"; }
err()    { printf '\033[1;31m xx\033[0m %s\n' "$*" >&2; }
note_fail() { FAILED+=("$1"); err "$1"; }

# Corre un comando mostrando su salida en pantalla y guardándola en el log.
# Nada de silenciar la salida: si pacman/yay/makepkg preguntan algo, se tiene
# que ver. Antes iba todo al log y una pregunta invisible parecía un cuelgue.
run_visible() {
  "$@" 2>&1 | tee -a "$LOG"
  return "${PIPESTATUS[0]}"
}

# Corre un comando y, si falla, lo anota sin abortar todo el script.
try() {
  local desc="$1"; shift
  info "$desc"
  if run_visible "$@"; then ok "$desc"; return 0
  else note_fail "$desc  (detalle en $LOG)"; return 1; fi
}

# Flags según el gestor. Los de yay/paru son los que evitan que se quede
# esperando respuesta: sin ellos pregunta por diffs, por editar el PKGBUILD y
# por cuál proveedor usar, y con la salida oculta eso parecía un cuelgue.
mgr_flags() {
  case "$1" in
    yay)  printf '%s ' -S --needed --noconfirm --answerclean=None \
                        --answerdiff=None --answeredit=None \
                        --answerupgrade=None --removemake --sudoloop ;;
    paru) printf '%s ' -S --needed --noconfirm --skipreview --removemake --sudoloop ;;
    *)        printf '%s ' -S --needed --noconfirm ;;
  esac
}

# Instala una lista de paquetes de una sola pasada; si el lote falla, reintenta
# uno por uno para que un solo paquete roto no tumbe la instalación entera.
install_batch() {
  local mgr="$1"; shift
  local -a pkgs=("$@")
  local -a flags; read -ra flags <<< "$(mgr_flags "${mgr##* }")"
  info "Instalando ${#pkgs[@]} paquetes con $mgr"
  info "(la salida va en vivo; también queda en $LOG)"
  if run_visible $mgr "${flags[@]}" "${pkgs[@]}"; then
    ok "los ${#pkgs[@]} paquetes quedaron instalados"; return 0
  fi
  warn "el lote falló; reintento uno por uno (esto tarda más)"
  local p i=0 n="${#pkgs[@]}"
  for p in "${pkgs[@]}"; do
    i=$(( i + 1 ))
    barra "$i" "$n" "$p"
    if run_visible $mgr "${flags[@]}" "$p"; then
      printf '   \033[1;32m✓\033[0m %s\n' "$p"
    else
      printf '   \033[1;31mx\033[0m %s\n' "$p"; FAILED+=("paquete: $p")
    fi
  done
}

# Pide la contraseña UNA sola vez y luego refresca el ticket de sudo en segundo
# plano, para que ni pacman ni makepkg ni yay la vuelvan a pedir a mitad de todo.
SUDO_LISTO=0
sudo_keepalive() {
  [ "$SUDO_LISTO" -eq 1 ] && return 0
  info "La instalación necesita sudo. Se te pedirá la contraseña una sola vez."
  sudo -v || { err "Sin sudo no se puede seguir."; exit 1; }
  ( while kill -0 "$$" 2>/dev/null; do
      sudo -n true 2>/dev/null || printf '\033[1;33m !!\033[0m el ticket de sudo caducó; el siguiente paso pedirá la contraseña\n'
      sleep 45
    done ) &
  SUDO_PID=$!
  trap 'kill "$SUDO_PID" 2>/dev/null' EXIT INT TERM
  SUDO_LISTO=1
  ok "sudo listo; no te la volverá a pedir"
}

# makepkg llama a sudo por su cuenta; con el ticket vivo no pregunta nada.
# --noconfirm evita además las preguntas interactivas de pacman.

# =============================================================================
#  SECCIÓN 0 — Preparación del sistema
# =============================================================================
sec0_preparacion() {
  b "0 · Preparación del sistema"
  [ "$(id -u)" -eq 0 ] && { err "No lo corras como root; usa tu usuario (pedirá sudo)."; exit 1; }
  command -v pacman >/dev/null || { err "Esto es para Arch/CachyOS: no encontré pacman."; exit 1; }
  mkdir -p "$WORKDIR"; : > "$LOG"
  info "Registro: $LOG"
  try "Sincronizando repos y actualizando el sistema" sudo pacman -Syu --noconfirm
}

# =============================================================================
#  SECCIÓN 1 — Herramientas de compilación y helper de AUR
#  Va antes que todo lo demás: sin base-devel no se compila nada del AUR.
# =============================================================================
sec1_toolchain() {
  b "1 · Herramientas de compilación y AUR"
  install_batch "sudo pacman" base-devel git rsync
  if command -v yay >/dev/null;  then AUR=yay;  ok "yay ya está instalado";  return; fi
  if command -v paru >/dev/null; then AUR=paru; ok "paru ya está instalado"; return; fi
  local d="$WORKDIR/yay-bin"
  rm -rf "$d"
  try "Clonando yay-bin" git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$d"
  ( cd "$d" && run_visible makepkg -si --noconfirm ) \
    && ok "yay instalado" || note_fail "no se pudo instalar yay"
  AUR=yay
}

# =============================================================================
#  SECCIÓN 2 — Dependencias de los repos oficiales
#  Primero estas: los metapaquetes de la sección 4 las dan por hechas y así
#  makepkg no tiene que resolver nada.
# =============================================================================
PKGS_REPO=(
  # base / utilidades de la shell
  bc coreutils cliphist cmake curl wget ripgrep jq xdg-user-dirs rsync go-yq
  # hyprland
  hyprland hyprsunset wl-clipboard hypridle hyprlock hyprpicker hyprshot
  # quickshell: runtime de Qt6
  cpptrace jemalloc mesa libdrm libpipewire libxcb wayland
  qt6-base qt6-declarative qt6-svg qt6-5compat qt6-imageformats qt6-multimedia
  qt6-positioning qt6-quicktimeline qt6-sensors qt6-tools qt6-translations
  qt6-virtualkeyboard qt6-wayland kirigami kdialog syntax-highlighting
  # widgets
  fuzzel glib2 imagemagick songrec translate-shell wlogout libqalculate
  # audio
  cava pavucontrol-qt wireplumber pipewire-pulse libdbusmenu-gtk3 playerctl
  # brillo y sensores
  geoclue brightnessctl ddcutil
  # captura de pantalla
  slurp swappy tesseract tesseract-data-eng wf-recorder
  # entrada
  upower wtype ydotool
  # portales xdg
  xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
  # sesión / kde
  bluedevil gnome-keyring networkmanager plasma-nm polkit-kde-agent dolphin systemsettings breeze
  # terminal, shell y tema
  fish starship kitty eza fontconfig matugen ttf-jetbrains-mono-nerd
  # python de la shell
  clang uv gtk4 libadwaita libsoup3 libportal-gtk4 gobject-introspection
)
sec2_repos() {
  b "2 · Dependencias de los repos oficiales (${#PKGS_REPO[@]})"
  install_batch "sudo pacman" "${PKGS_REPO[@]}"
}

# =============================================================================
#  SECCIÓN 3 — Dependencias del AUR
#  Van ANTES de los metapaquetes: makepkg solo resuelve dependencias de los
#  repos oficiales, así que si estas faltan la sección 4 falla entera.
# =============================================================================
PKGS_AUR=(
  adw-gtk-theme-git breeze-plus darkly-bin qt6-avif-image-plugin
  otf-space-grotesk ttf-material-symbols-variable-git ttf-readex-pro
  ttf-rubik-vf ttf-twemoji
)
sec3_aur() {
  b "3 · Dependencias del AUR (${#PKGS_AUR[@]})"
  command -v "${AUR:-yay}" >/dev/null || { note_fail "no hay helper de AUR; corre la sección 1"; return 1; }
  install_batch "${AUR:-yay}" "${PKGS_AUR[@]}"
}

# =============================================================================
#  SECCIÓN 4 — Metapaquetes illogical-impulse-*
#  "illogical impulse" es el rice de end-4: sus metapaquetes viven en su repo
#  (sdata/dist-arch) y no están publicados en el AUR, así que se compilan aquí.
#  Se construyen en orden: primero los livianos, quickshell al final porque es
#  el que más tarda.
# =============================================================================
META_ORDER=(
  illogical-impulse-basic
  illogical-impulse-hyprland
  illogical-impulse-toolkit
  illogical-impulse-portal
  illogical-impulse-kde
  illogical-impulse-audio
  illogical-impulse-backlight
  illogical-impulse-screencapture
  illogical-impulse-widgets
  illogical-impulse-fonts-themes
  illogical-impulse-python
  illogical-impulse-bibata-modern-classic-bin
  illogical-impulse-quickshell-git
)
sec4_metapaquetes() {
  b "4 · Metapaquetes illogical-impulse-* (${#META_ORDER[@]})"
  mkdir -p "$WORKDIR"
  local repo="$WORKDIR/dots-hyprland"
  if [ -d "$repo/.git" ]; then
    try "Actualizando el repo de end-4" git -C "$repo" pull --ff-only
  else
    try "Clonando end-4/dots-hyprland" git clone --depth 1 "$UPSTREAM" "$repo" || return 1
  fi

  local dist="$repo/sdata/dist-arch"
  [ -d "$dist" ] || { note_fail "no existe $dist (el upstream cambió); instala a mano según packages.txt"; return 1; }

  local m i=0 n="${#META_ORDER[@]}"
  for m in "${META_ORDER[@]}"; do
    i=$(( i + 1 ))
    if [ ! -f "$dist/$m/PKGBUILD" ]; then warn "$m ya no está en el upstream, lo salto"; continue; fi
    barra "$i" "$n" "$m"
    info "compilando $m  (quickshell puede tardar varios minutos)"
    if ( cd "$dist/$m" && run_visible makepkg -si --noconfirm --needed ); then
      ok "$m"
    else
      note_fail "$m no se pudo instalar"
    fi
  done
}

# =============================================================================
#  SECCIÓN 5 — Entorno Python de la shell
#  Necesita 'uv', que llega en la sección 2. La lista fijada la manda el upstream.
# =============================================================================
sec5_venv() {
  b "5 · Entorno Python (uv)"
  command -v uv >/dev/null || { note_fail "falta uv (sección 2)"; return 1; }
  mkdir -p "$(dirname "$VENV")"
  try "Creando el venv en $VENV" uv venv --prompt .venv -p 3.12 "$VENV" || return 1

  local req="$WORKDIR/dots-hyprland/sdata/uv/requirements.txt"
  if [ -f "$req" ]; then
    VIRTUAL_ENV="$VENV" try "Instalando requirements.txt del upstream" uv pip install -r "$req"
  else
    warn "sin requirements.txt del upstream; uso la lista de respaldo"
    VIRTUAL_ENV="$VENV" try "Instalando paquetes de Python" uv pip install \
      build pillow setuptools-scm wheel pywayland psutil kde-material-you-colors \
      materialyoucolor libsass material-color-utilities setproctitle click loguru \
      pycairo pygobject tqdm numpy opencv-contrib-python google-auth requests
  fi
  # Extras que usan mis widgets de correo/cuentas (no vienen en el upstream)
  VIRTUAL_ENV="$VENV" try "Instalando extras de correo/cuentas" uv pip install dbus-python cryptography
}

# =============================================================================
#  SECCIÓN 6 — Fuentes
# =============================================================================
sec6_fuentes() {
  b "6 · Fuentes"
  local dst="$HOME/.local/share/fonts/illogical-impulse-google-sans-flex"
  if [ -d "$dst/.git" ]; then
    try "Actualizando Google Sans Flex" git -C "$dst" pull --ff-only
  else
    mkdir -p "$(dirname "$dst")"
    try "Clonando Google Sans Flex" git clone --depth 1 "$FONT_REPO" "$dst"
  fi
  try "Refrescando la caché de fuentes" fc-cache -f
}

# =============================================================================
#  SECCIÓN 7 — Extras opcionales (mis apps, no hacen falta para la shell)
# =============================================================================
PKGS_EXTRA=( micro foot mpv btop fastfetch visual-studio-code-bin spotify )
sec7_extras() {
  b "7 · Extras opcionales (${#PKGS_EXTRA[@]})"
  [ "$SKIP_EXTRAS" -eq 1 ] && { info "omitidos (--skip-extras)"; return 0; }
  install_batch "${AUR:-yay}" "${PKGS_EXTRA[@]}"
}

# =============================================================================
#  SECCIÓN 8 — Servicios
#  Después de instalar: las unidades no existen hasta que están los paquetes.
# =============================================================================
sec8_servicios() {
  b "8 · Servicios"
  local s
  for s in bluetooth NetworkManager; do
    sudo systemctl enable --now "$s.service" >>"$LOG" 2>&1 && ok "$s" || warn "$s no se pudo habilitar"
  done
  for s in ydotool pipewire.socket pipewire-pulse.socket wireplumber gnome-keyring-daemon.socket; do
    systemctl --user enable --now "$s" >>"$LOG" 2>&1 && ok "usuario: $s" || warn "usuario: $s no disponible"
  done
  if ! id -nG | tr ' ' '\n' | grep -qx input; then
    sudo usermod -aG input "$USER" >>"$LOG" 2>&1 \
      && warn "te agregué al grupo 'input' (ydotool): hace falta reiniciar sesión" \
      || warn "no pude agregarte al grupo 'input'"
  else
    ok "ya estás en el grupo 'input'"
  fi
}

# =============================================================================
#  SECCIÓN 9 — Configuración: dotfiles + shim + colores iniciales
# =============================================================================
sec9_dotfiles() {
  b "9 · Configuración"
  [ -x "$SRC/install.sh" ] || { note_fail "no encuentro install.sh junto a setup.sh"; return 1; }
  "$SRC/install.sh" || note_fail "install.sh terminó con errores"
}

# =============================================================================
#  SECCIÓN 10 — Fork de referencia (no se instala, solo para consultar)
# =============================================================================
sec10_referencia() {
  b "10 · Fork de referencia end4-pC"
  local dst="$HOME/.config/quickshell/end4-pC"
  if [ -d "$dst/.git" ]; then ok "ya está en $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  try "Clonando end4-pC" git clone --depth 1 "$FORK" "$dst"
}

# =============================================================================
#  SECCIÓN 11 — Verificación final
# =============================================================================
sec11_verificacion() {
  b "11 · Verificación"
  [ -x "$SRC/doctor.sh" ] && "$SRC/doctor.sh" || warn "no encontré doctor.sh"
}

# -----------------------------------------------------------------------------
#  Orquestación
# -----------------------------------------------------------------------------
SECCIONES=(
  sec0_preparacion sec1_toolchain sec2_repos sec3_aur sec4_metapaquetes
  sec5_venv sec6_fuentes sec7_extras sec8_servicios sec9_dotfiles
  sec10_referencia sec11_verificacion
)
NOMBRES=(
  "Preparación del sistema" "Herramientas de compilación y AUR"
  "Dependencias de repos oficiales" "Dependencias del AUR"
  "Metapaquetes illogical-impulse-*" "Entorno Python (uv)" "Fuentes"
  "Extras opcionales" "Servicios" "Configuración (dotfiles + shim)"
  "Fork de referencia" "Verificación final"
)

listar() { local i; for i in "${!NOMBRES[@]}"; do printf '  %2d  %s\n' "$i" "${NOMBRES[$i]}"; done; }

resumen() {
  echo
  barra "$SEC_TOTAL" "$SEC_TOTAL" "terminado"
  if [ "${#FAILED[@]}" -eq 0 ]; then
    printf '\033[1;32m━━ Instalación completa, sin errores ━━\033[0m\n'
  else
    printf '\033[1;33m━━ Terminó con %d problema(s) ━━\033[0m\n' "${#FAILED[@]}"
    printf '   • %s\n' "${FAILED[@]}"
    printf '   Log completo: %s\n' "$LOG"
    printf '   Puedes reanudar con: ./setup.sh --from <n>\n'
  fi
  echo
  echo "  1. Ajusta ~/.config/hypr/monitors.conf a tus pantallas."
  echo "  2. Revisa 'wallpaperPath' en ~/.config/illogical-impulse/config.json."
  echo "  3. Cierra sesión y entra en Hyprland (o: hyprctl reload && qs -c ii)."
  echo "  4. ¿Algo no carga? ./doctor.sh"
}

# ------------------------------------------------------------------ argumentos
while [ $# -gt 0 ]; do
  case "$1" in
    --list)        listar; exit 0 ;;
    --only)        ONLY="$2"; shift 2 ;;
    --from)        FROM="$2"; shift 2 ;;
    --skip-extras) SKIP_EXTRAS=1; shift ;;
    --yes|-y)      ASSUME_YES=1; shift ;;
    --deps)        ONLY="2,3,4"; shift ;;
    --venv)        ONLY="5"; shift ;;
    --fonts)       ONLY="6"; shift ;;
    --dots)        ONLY="9"; shift ;;
    --upstream)    ONLY="10"; shift ;;
    --check)       ONLY="11"; shift ;;
    -h|--help)     sed -n '2,28p' "$0"; exit 0 ;;
    *)             err "Opción desconocida: $1"; echo; listar; exit 1 ;;
  esac
done

mkdir -p "$WORKDIR"; : > "$LOG"

# Secciones que tocan el sistema y por tanto necesitan root.
NECESITAN_SUDO=(0 1 2 3 4 7 8)
requiere_sudo() {
  local n s
  for n in "$@"; do
    for s in "${NECESITAN_SUDO[@]}"; do [ "$n" -eq "$s" ] && return 0; done
  done
  return 1
}

if [ -n "$ONLY" ]; then
  # Las secciones sueltas también necesitan el helper de AUR resuelto.
  command -v yay >/dev/null && AUR=yay || { command -v paru >/dev/null && AUR=paru || AUR=yay; }
  IFS=',' read -ra sel <<< "$ONLY"
  for n in "${sel[@]}"; do
    [ "$n" -ge 0 ] 2>/dev/null && [ "$n" -lt "${#SECCIONES[@]}" ] || { err "sección inválida: $n"; exit 1; }
  done
  requiere_sudo "${sel[@]}" && sudo_keepalive
  SEC_TOTAL="${#sel[@]}"; SEC_ACTUAL=0
  for n in "${sel[@]}"; do SEC_ACTUAL=$(( SEC_ACTUAL + 1 )); "${SECCIONES[$n]}"; done
  resumen
  exit 0
fi

if [ "$ASSUME_YES" -eq 0 ]; then
  echo "Se va a instalar Hyprland + Quickshell (ii) y aplicar la configuración."
  listar
  read -rp $'\n¿Seguimos? [S/n] ' r
  case "$r" in [nN]*) echo "cancelado"; exit 0 ;; esac
fi

# Una sola petición de contraseña para toda la corrida.
sudo_keepalive

SEC_TOTAL="${#SECCIONES[@]}"
for i in "${!SECCIONES[@]}"; do
  [ "$i" -lt "$FROM" ] && continue
  SEC_ACTUAL=$(( i + 1 ))
  "${SECCIONES[$i]}"
done
resumen
