# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != "linux"
        starship init fish | source
        enable_transience
    end
    
    # Colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != "linux"
        alias ls 'eza --icons'
    end
    if test "$TERM" = "xterm-kitty"
        alias ssh 'kitten ssh'
    end
end

# --- Arranque automatico de Hyprland -------------------------------------
# Solo al loguearse en la consola de tty1. Las guardas importan:
#   status is-login  -> no se dispara en cada terminal de adentro de la sesion
#   WAYLAND_DISPLAY  -> no reentra si ya hay un compositor andando
#   XDG_VTNR = 1     -> tty2..tty6 quedan como consola normal (salida de
#                       emergencia con Ctrl+Alt+F2 si Hyprland no levanta)
# La contrasenia la pide hyprlock, que arranca junto con la sesion
# (ver ~/.config/hypr/custom/execs.conf).
if status is-login
    and test -z "$WAYLAND_DISPLAY"
    and test "$XDG_VTNR" = 1
    exec hyprland
end
