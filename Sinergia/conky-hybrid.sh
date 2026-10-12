#!/bin/bash
# ==========================================================
#  TEMA CONKY HYBRID (ESCALA DE GRISES) - MULTI-ESCRITORIO
#  Arch Linux: MATE, XFCE, GNOME, KDE, Cinnamon, LXQt, Budgie,
#  Enlightenment, Trinity (TDE), Fluxbox, IceWM, Openbox,
#  i3, sway, bspwm y gestores de ventanas sueltos.
#
#  Cambios respecto a la versión anterior:
#   - La detección de interfaces de red y de CPUs ya NO se hornea
#     en la instalación: se hace en cada login (sirve si clonas
#     el disco a otro equipo).
#   - El conteo de CPUs usa /proc/stat (igual que Conky).
#   - Un único lanzador /usr/local/bin/hybrid-conky-start, con
#     bloqueo (flock) para que nunca arranque dos veces.
#   - Autostart XDG (MATE/XFCE/GNOME/KDE/Cinnamon/LXQt/Budgie),
#     autostart propio de Trinity, Enlightenment, Fluxbox,
#     IceWM, Openbox, i3, sway y bspwm.
#   - Dependencias comprobadas (python, yay/paru, Cairo/Lua en conky).
#   - Ya NO se debe ejecutar como root: usa sudo internamente.
#   - Detección de Cairo/Lua más robusta (con respaldo vía strings).
#   - Sustitución de conky por conky-lua-nv más segura (sin -Rdd
#     a la ligera).
#   - Aviso si la sesión es Wayland (Conky va vía XWayland).
# ==========================================================

set -uo pipefail

# ---------- Seguridad: no ejecutar como root ----------
if [ "$(id -u)" -eq 0 ]; then
    echo "==> ERROR: ejecuta este script SIN sudo. Él pedirá sudo cuando lo necesite."
    echo "    (Si lo lanzas con sudo, yay/paru y \$HOME se comportan raro.)"
    exit 1
fi

echo "==> Instalando el tema Conky Hybrid (multi-escritorio)..."

REAL_USER="${REAL_USER:-$(id -un)}"
USER_HOME="${USER_HOME:-$(getent passwd "$REAL_USER" | cut -d: -f6)}"
[ -d "$USER_HOME" ] || USER_HOME=$(eval echo "~$REAL_USER")
: "${USER_HOME:?No se pudo determinar USER_HOME}"

# Aviso Wayland (informativo, no bloquea)
if [ "${XDG_SESSION_TYPE:-x11}" = "wayland" ]; then
    echo "==> Wayland detectado: Conky se ejecutará a través de XWayland."
fi

# ---------- Dependencias ----------
sudo pacman -S --needed --noconfirm python unzip util-linux iproute2 noto-fonts fontconfig

conky_has_cairo() {
    command -v conky >/dev/null 2>&1 || return 1
    conky --version 2>/dev/null | grep -qiE 'cairo|lua' && return 0
    # Respaldo: buscar símbolos de Cairo en el binario
    strings "$(command -v conky)" 2>/dev/null | grep -qi 'cairo' && return 0
    return 1
}

if ! command -v conky >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm conky
fi

if ! conky_has_cairo; then
    echo "==> El conky instalado no trae bindings de Cairo/Lua; probando conky-lua-nv (AUR)..."
    AUR_HELPER=""
    for h in yay paru; do
        command -v "$h" >/dev/null 2>&1 && AUR_HELPER="$h" && break
    done
    if [ -n "$AUR_HELPER" ]; then
        # Intento normal primero; -Rdd solo como último recurso y avisando.
        if ! sudo pacman -R --noconfirm conky 2>/dev/null; then
            echo "==> ADVERTENCIA: 'pacman -R conky' falló; forzando con -Rdd."
            echo "    Revisa dependencias rotas con 'pacman -Qtdq' tras la instalación."
            sudo pacman -Rdd --noconfirm conky 2>/dev/null || true
        fi
        "$AUR_HELPER" -S --needed --noconfirm conky-lua-nv
    else
        echo "==> ADVERTENCIA: no hay yay ni paru; instala conky-lua-nv a mano"
        echo "    o los anillos no se dibujarán."
    fi
fi
conky_has_cairo || echo "==> ADVERTENCIA: conky sigue sin soporte Cairo."

# ---------- Tema embebido (base64 de un .zip) ----------
HYBRID_B64_FILE="/tmp/hybrid_theme.b64"
HYBRID_ZIP="/tmp/hybrid.zip"
HYBRID_EXTRACT_DIR="/tmp/hybrid_extract"

cat > "$HYBRID_B64_FILE" << 'HYBRID_B64_EOF'
__BLOB__
HYBRID_B64_EOF

hybrid_install_main() {
    base64 -d "$HYBRID_B64_FILE" > "$HYBRID_ZIP" 2>/dev/null
    rm -f "$HYBRID_B64_FILE"

    if [ ! -s "$HYBRID_ZIP" ]; then
        echo "==> ERROR: no se pudo decodificar el tema Conky Hybrid embebido."
        return 1
    fi

    rm -rf "$HYBRID_EXTRACT_DIR"
    mkdir -p "$HYBRID_EXTRACT_DIR"
    if ! unzip -o -q "$HYBRID_ZIP" -d "$HYBRID_EXTRACT_DIR"; then
        echo "==> ERROR: no se pudo descomprimir el tema Conky Hybrid."
        return 1
    fi

    local T="$HYBRID_EXTRACT_DIR/hybrid"

    # Los archivos que dependen de la máquina pasan a ser plantillas;
    # el lanzador los genera en cada login.
    mv "$T/hybrid.conf" "$T/hybrid.conf.tpl"
    mv "$T/lua/hybrid-rings.lua" "$T/lua/hybrid-rings.lua.tpl"
    rm -f "$T/startup/hybrid-startup.sh"
    mkdir -p "$T/startup"

    # --- Recorte de anillos de CPU (se ejecuta en cada login) ---
    cat > "$T/startup/hybrid-prepare.py" << 'HYBRID_PY_EOF'
#!/usr/bin/env python3
# Genera lua/hybrid-rings.lua quitando los anillos cpuN que no existen.
# Conky aborta ("attempting to use more CPUs than you have") si se
# pide un CPU inexistente. Se cuenta con la misma fuente que Conky.
import os, re, sys

d = sys.argv[1]
src = os.path.join(d, "lua", "hybrid-rings.lua.tpl")
dst = os.path.join(d, "lua", "hybrid-rings.lua")

with open("/proc/stat") as f:
    nproc = max(sum(1 for l in f if re.match(r"cpu\d+\s", l)), 1)

with open(src, "r", encoding="utf-8") as f:
    text = f.read()

marker = "settings_table = {"
tbl_start = text.index(marker)
brace_open = tbl_start + len(marker) - 1

depth = 0
entries = []
entry_start = None
for i in range(brace_open, len(text)):
    ch = text[i]
    if ch == "{":
        depth += 1
        if depth == 2:
            entry_start = i
    elif ch == "}":
        if depth == 2:
            entries.append((entry_start, i + 1))
        depth -= 1
        if depth == 0:
            break

to_remove = []
for s, e in entries:
    block = text[s:e]
    if "name='cpu'" in block:
        m = re.search(r"arg='cpu(\d+)'", block)
        if m and int(m.group(1)) > nproc:
            end_ext = e + 1 if e < len(text) and text[e] == "," else e
            to_remove.append((s, end_ext))

for s, e in sorted(to_remove, key=lambda t: -t[0]):
    text = text[:s] + text[e:]
text = re.sub(r"(\n[ \t]*){3,}", "\n\n", text)

with open(dst, "w", encoding="utf-8") as f:
    f.write(text)
HYBRID_PY_EOF

    # --- Despliegue en el usuario real y en /etc/skel ---
    hybrid_deploy() {
        local HOME_DIR="$1" USER_NAME="$2"
        sudo mkdir -p "$HOME_DIR/.config/conky"
        sudo rm -rf "$HOME_DIR/.config/conky/hybrid"
        sudo cp -r "$T" "$HOME_DIR/.config/conky/hybrid"
        if [ "$USER_NAME" != "root" ]; then
            sudo chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.config/conky"
        fi
    }
    hybrid_deploy "$USER_HOME" "$REAL_USER"
    hybrid_deploy "/etc/skel" "root"

    # --- Fuentes (NotoSans ya instalada vía pacman) ---
    if compgen -G "$T/fonts/*.ttf" > /dev/null; then
        sudo mkdir -p /usr/share/fonts/hybrid-conky
        sudo cp "$T/fonts/"*.ttf /usr/share/fonts/hybrid-conky/
        sudo fc-cache -f > /dev/null 2>&1
    fi

    # --- Lanzador único ---
    sudo tee /usr/local/bin/hybrid-conky-start > /dev/null << 'HYBRID_LAUNCHER_EOF'
#!/bin/sh
# Lanzador del tema Conky Hybrid. Idempotente y apto para cualquier escritorio.
D="$HOME/.config/conky/hybrid"
[ -f "$D/hybrid.conf.tpl" ] || exit 0

# Bloqueo: si ya hay una instancia (p.ej. XDG + TDE a la vez), salir.
# El descriptor 9 lo hereda conky, así que el bloqueo dura lo que dure conky.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/hybrid-conky-$(id -u).lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

# Interfaces reales (se ignoran lo, veth, docker, bridges, etc.)
WIRED=""; WIFI=""
for p in /sys/class/net/*; do
    i=${p##*/}
    [ "$i" = "lo" ] && continue
    case "$(readlink -f "$p")" in */virtual/*) continue ;; esac
    if [ -d "$p/wireless" ]; then
        [ -z "$WIFI" ] && WIFI=$i
    else
        [ -z "$WIRED" ] && WIRED=$i
    fi
done
WIRED=${WIRED:-none0}
WIFI=${WIFI:-none1}

sed -e "s/__IFACE_WIRED1__/$WIRED/g" \
    -e "s/__IFACE_WIFI1__/$WIFI/g" \
    "$D/hybrid.conf.tpl" > "$D/hybrid.conf"

if command -v python3 >/dev/null 2>&1; then
    python3 "$D/startup/hybrid-prepare.py" "$D" || cp "$D/lua/hybrid-rings.lua.tpl" "$D/lua/hybrid-rings.lua"
else
    cp "$D/lua/hybrid-rings.lua.tpl" "$D/lua/hybrid-rings.lua"
fi

# Espera a que el escritorio/compositor esté listo
sleep "${HYBRID_DELAY:-5}"
exec conky -c "$D/hybrid.conf"
HYBRID_LAUNCHER_EOF
    sudo chmod 755 /usr/local/bin/hybrid-conky-start

    # --- Autostart: XDG (casi todos) + Trinity + Enlightenment + WMs ---
    hybrid_autostart() {
        local HOME_DIR="$1" USER_NAME="$2"

        # ---------- XDG autostart ----------
        # Cubre: MATE, XFCE, GNOME, KDE, Cinnamon, LXQt, Budgie.
        sudo mkdir -p "$HOME_DIR/.config/autostart"
        sudo tee "$HOME_DIR/.config/autostart/hybrid-conky.desktop" > /dev/null << 'HYBRID_DESKTOP_EOF'
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/hybrid-conky-start
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Name=Hybrid Conky
Comment=Inicia el tema Conky Hybrid (escala de grises) al iniciar sesión
HYBRID_DESKTOP_EOF

        # ---------- Trinity (TDE) ----------
        sudo mkdir -p "$HOME_DIR/.trinity/Autostart"
        sudo tee "$HOME_DIR/.trinity/Autostart/hybrid-conky.sh" > /dev/null << 'HYBRID_TDE_EOF'
#!/bin/sh
exec /usr/local/bin/hybrid-conky-start
HYBRID_TDE_EOF
        sudo chmod +x "$HOME_DIR/.trinity/Autostart/hybrid-conky.sh"

        # ---------- Enlightenment ----------
        sudo mkdir -p "$HOME_DIR/.e/e/applications/startup"
        echo "hybrid-conky-start" | sudo tee "$HOME_DIR/.e/e/applications/startup/.order" >/dev/null

        # ---------- Fluxbox ----------
        if [ -d "$HOME_DIR/.fluxbox" ]; then
            if ! sudo grep -q 'hybrid-conky-start' "$HOME_DIR/.fluxbox/startup" 2>/dev/null; then
                echo '/usr/local/bin/hybrid-conky-start &' | sudo tee -a "$HOME_DIR/.fluxbox/startup" >/dev/null
            fi
        fi

        # ---------- IceWM ----------
        if [ -d "$HOME_DIR/.icewm" ]; then
            if ! sudo grep -q 'hybrid-conky-start' "$HOME_DIR/.icewm/startup" 2>/dev/null; then
                echo '/usr/local/bin/hybrid-conky-start &' | sudo tee -a "$HOME_DIR/.icewm/startup" >/dev/null
            fi
        fi

        # ---------- Openbox ----------
        if [ -d "$HOME_DIR/.config/openbox" ]; then
            if ! sudo grep -q 'hybrid-conky-start' "$HOME_DIR/.config/openbox/autostart" 2>/dev/null; then
                echo '/usr/local/bin/hybrid-conky-start &' | sudo tee -a "$HOME_DIR/.config/openbox/autostart" >/dev/null
            fi
        fi

        # ---------- i3 / sway ----------
        for wm_cfg in "$HOME_DIR/.config/i3/config" "$HOME_DIR/.config/sway/config"; do
            if [ -f "$wm_cfg" ] && ! sudo grep -q 'hybrid-conky-start' "$wm_cfg"; then
                echo 'exec_always --no-startup-id /usr/local/bin/hybrid-conky-start' | sudo tee -a "$wm_cfg" >/dev/null
            fi
        done

        # ---------- bspwm ----------
        if [ -f "$HOME_DIR/.config/bspwm/bspwmrc" ] && \
           ! sudo grep -q 'hybrid-conky-start' "$HOME_DIR/.config/bspwm/bspwmrc"; then
            echo '/usr/local/bin/hybrid-conky-start &' | sudo tee -a "$HOME_DIR/.config/bspwm/bspwmrc" >/dev/null
        fi

        # ---------- Permisos ----------
        if [ "$USER_NAME" != "root" ]; then
            sudo chown -R "$USER_NAME:$USER_NAME" \
                "$HOME_DIR/.config/autostart" \
                "$HOME_DIR/.trinity" \
                "$HOME_DIR/.e" 2>/dev/null || true
        fi
    }
    hybrid_autostart "$USER_HOME" "$REAL_USER"
    hybrid_autostart "/etc/skel" "root"

    echo "==> Tema Conky Hybrid instalado. Se configura solo en cada login."
    echo "==> Si usas dwm, JWM, WindowMaker u otro WM sin autostart estándar,"
    echo "    añade a mano a su config:  hybrid-conky-start &"
}

hybrid_install_main
rm -rf "$HYBRID_EXTRACT_DIR" "$HYBRID_ZIP" "$HYBRID_B64_FILE"
