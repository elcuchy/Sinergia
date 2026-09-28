#!/bin/bash

# Exit on error, on unset variables, and propagate errors through pipes
set -euo pipefail

# Aviso de en qué línea falló el script, si falla
trap 'echo "==> ERROR: el script falló en la línea $LINENO (comando: $BASH_COMMAND)" >&2' ERR

# Identificar usuario real (en caso de ejecutar con sudo)
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO Y PACMAN
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
fi

echo "==> Activando ILoveCandy y descargas paralelas en pacman.conf..."
if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi

if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/g' /etc/pacman.conf
elif ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a ParallelDownloads = 5' /etc/pacman.conf
fi


# ==========================================
# 2. CONFIGURACIÓN DEL REPOSITORIO NEMESIS_REPO (KIRO)
# ==========================================
echo "==> Configurando el repositorio nemesis_repo..."

# Aseguramos que el keyring de pacman esté inicializado antes de importar claves
sudo pacman-key --init 2>/dev/null || true

if ! grep -q "\[nemesis_repo\]" /etc/pacman.conf; then
    echo "==> Agregando repositorio temporal nemesis_repo para bootstrap..."
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[nemesis_repo]
Server = https://erikdubois.github.io/\$repo/\$arch
EOF'
fi

sudo pacman -Sy

echo "==> Importando clave PGP de Kiro (149ABD0C3A0563EE)..."
sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keyserver.ubuntu.com || \
sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keys.openpgp.org || \
{ sleep 5; sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keyserver.ubuntu.com; }

sudo pacman-key --lsign-key 149ABD0C3A0563EE

echo "==> Instalando kiro-keyring y kiro-mirrorlist..."
sudo pacman -Sy --needed kiro-keyring kiro-mirrorlist --noconfirm

echo "==> Actualizando pacman.conf para usar kiro-mirrorlist..."
sudo sed -i 's|Server = https://erikdubois.github.io/\$repo/\$arch|Include = /etc/pacman.d/kiro-mirrorlist|g' /etc/pacman.conf


# ==========================================
# 3. CONFIGURACIÓN DEL REPOSITORIO CHAOTIC-AUR
# ==========================================
echo "==> Configurando el repositorio Chaotic-AUR..."

sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || \
sudo pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com:443 || \
{ sleep 5; sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; }
sudo pacman-key --lsign-key 3056513887B78AEB

sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo "==> Agregando [chaotic-aur] a pacman.conf..."
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF'
fi

echo "==> Actualizando la base de datos de repositorios..."
sudo pacman -Sy


# ==========================================
# 4. INSTALACIÓN DE PAQUETES OFICIALES Y CHAOTIC-AUR
# ==========================================
echo "==> Instalando Enlightenment, LightDM, aplicaciones, dependencias y paquetes del sistema..."
sudo pacman -S --noconfirm --needed \
  enlightenment \
  lightdm \
  lightdm-slick-greeter \
  connman \
  ecrire \
  ephoto \
  evisum \
  rage \
  packagekit \
  amd-ucode \
  intel-ucode \
  atril \
  vlc \
  unrar \
  p7zip \
  chromium \
  firefox \
  firefox-i18n-es-ar \
  libreoffice-fresh-es \
  hunspell-es_uy \
  telegram-desktop \
  zsh \
  zsh-completions \
  fastfetch \
  ntfs-3g \
  archlinux-tweak-tool-gtk4 \
  terminology \
  vlc-plugins-all \
  hardinfo2 \
  mpv \
  btop \
  gparted \
  nano \
  audacious \
  shelly \
  gvfs-dnssd \
  gvfs-wsdd \
  rygel \
  tracker3-miners \
  gvfs \
  gvfs-afc \
  gvfs-gphoto2 \
  gvfs-mtp \
  gvfs-nfs \
  gvfs-smb \
  transmission-gtk \
  xarchiver \
  obs-studio \
  audacity \
  ardour \
  kdenlive \
  ventoy \
  papirus-icon-theme \
  yaru-icon-theme \
  mint-l-icons \
  mint-x-icons \
  mint-y-icons \
  mate-icon-theme-faenza \
  rustdesk-bin \
  os-prober


# ==========================================
# 5. INSTALACIÓN DE YAY Y PAQUETES AUR
# ==========================================
echo "==> Asegurando base-devel e instalando YAY..."
sudo pacman -S --needed base-devel git --noconfirm

if command -v yay >/dev/null 2>&1; then
    echo "==> yay ya está instalado, se omite la compilación."
else
    BUILD_DIR=$(mktemp -d)
    sudo chown -R "$REAL_USER:$REAL_USER" "$BUILD_DIR"

    sudo -u "$REAL_USER" bash -c "
      git clone https://aur.archlinux.org/yay.git '$BUILD_DIR/yay'
      cd '$BUILD_DIR/yay'
      makepkg -si --noconfirm
    "
    rm -rf "$BUILD_DIR"
fi

echo "==> Instalando paquetes AUR adicionales..."
sudo -u "$REAL_USER" yay -S --needed --noconfirm \
  stacer-bin \
  sinergia-dd-burner \
  iptvnator-bin \
  yaru-colors-icon-theme \
  fetch-git

# ==========================================
# 6. CONFIGURACIÓN DE SYSTEM SERVICES Y GRUB
# ==========================================
echo "==> Configurando LightDM con Slick Greeter como display manager por defecto..."

# Si hay otro DM habilitado, lo deshabilitamos para evitar conflictos
for dm in entrance gdm sddm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        echo "==> Deshabilitando $dm..."
        sudo systemctl disable "$dm"
    fi
done

sudo sed -i 's/#\?greeter-session=.*/greeter-session=lightdm-slick-greeter/' /etc/lightdm/lightdm.conf
sudo systemctl enable lightdm
sudo systemctl enable connman

echo "==> Configurando GRUB para detectar otros SO..."
if [ -f /etc/default/grub ]; then
    sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi


# ==========================================
# 7. TEMA, ICONOS Y FONDO DE PANTALLA POR DEFECTO
# ==========================================
# Tema:   Dimensions (e25) de simotek - https://www.gnome-look.org/p/1795915
#         (se descarga del release oficial del autor en GitHub)
# Iconos: Yaru-blue-dark (paquete yaru-icon-theme), habilitado también para Enlightenment
# Fondo:  archlinux-wallpapers / 30.png
#
# Enlightenment guarda su configuración en archivos binarios (e.cfg). Aquí se
# modifican los perfiles del SISTEMA, así cada usuario nuevo arranca ya con el
# tema, los iconos y el fondo. Un hook de pacman los vuelve a aplicar cada vez
# que se actualiza el paquete enlightenment.

E_THEME_TAG="20220516.1.26"
E_THEME_FILE="Dimensions.edj"
ICON_THEME="Yaru-blue-dark"
WALLPAPER_URL="https://raw.githubusercontent.com/f4dzN/archlinux-wallpapers/refs/heads/main/wallpapers/30.png"

E_THEMES_DIR="/usr/share/enlightenment/data/themes"
ELM_THEMES_DIR="/usr/share/elementary/themes"
E_BG_DIR="/usr/share/enlightenment/data/backgrounds"
WALLPAPER_PNG="/usr/share/backgrounds/comunidad-linuxera/30.png"
WALLPAPER_EDJ="$E_BG_DIR/linuxera-30.edj"
LOOK_TMP=$(mktemp -d)

# Fija clave=valor dentro de una [sección] de un archivo .ini (lo edita en el lugar)
ini_set() {
    local file=$1 section=$2 key=$3 value=$4 out
    out=$(mktemp)
    awk -v s="[$section]" -v k="$key" -v v="$value" '
        BEGIN { seen = 0; insec = 0; done = 0 }
        $0 == s { print; seen = 1; insec = 1; next }
        /^\[/ { if (insec && !done) { print k "=" v; done = 1 } insec = 0; print; next }
        insec && index($0, k) == 1 && $0 ~ ("^" k "[ \t]*=") { if (!done) { print k "=" v; done = 1 } next }
        { print }
        END { if (!done) { if (!seen) print s; print k "=" v } }' "$file" > "$out"
    cat "$out" > "$file"
    rm -f "$out"
}

# ---------- 7.1 Iconos ----------
echo "==> Verificando el tema de iconos $ICON_THEME..."
if [ ! -d "/usr/share/icons/$ICON_THEME" ]; then
    ICON_ALT=$(find /usr/share/icons -maxdepth 1 -type d -iname "$ICON_THEME" -printf '%f\n' 2>/dev/null | head -n1 || true)
    if [ -n "$ICON_ALT" ]; then
        ICON_THEME="$ICON_ALT"
    else
        echo "==> Aviso: no se encontró /usr/share/icons/$ICON_THEME (¿se instaló yaru-icon-theme?). Se configura igual."
    fi
fi

# ---------- 7.2 Tema Dimensions ----------
echo "==> Descargando el tema 'Dimensions' para Enlightenment..."
THEME_OK=0
THEME_URL=$(curl -fsSL "https://api.github.com/repos/simotek/Enlightenment-Themes/releases/tags/$E_THEME_TAG" 2>/dev/null \
    | grep -oE 'https://[^"]+\.edj' | grep -E '/Dimensions[^/]*\.edj$' | head -n1 || true)

if [ -n "$THEME_URL" ] && curl -fsSL --retry 3 -o "$LOOK_TMP/$E_THEME_FILE" "$THEME_URL"; then
    sudo install -Dm644 "$LOOK_TMP/$E_THEME_FILE" "$E_THEMES_DIR/$E_THEME_FILE"
    # El mismo .edj sirve para las aplicaciones EFL/Elementary
    sudo install -Dm644 "$LOOK_TMP/$E_THEME_FILE" "$ELM_THEMES_DIR/$E_THEME_FILE"
    THEME_OK=1
else
    echo "==> Aviso: no se pudo descargar el tema Dimensions; Enlightenment usará su tema por defecto."
fi

# ---------- 7.3 Fondo de pantalla ----------
# Enlightenment no usa PNG directamente como fondo: hay que empaquetarlo en un .edj
echo "==> Descargando y preparando el fondo de pantalla..."
BG_OK=0
if curl -fsSL --retry 3 -o "$LOOK_TMP/30.png" "$WALLPAPER_URL"; then
    sudo install -Dm644 "$LOOK_TMP/30.png" "$WALLPAPER_PNG"

    # Relación de aspecto para que el fondo cubra la pantalla sin deformarse
    ASPECT_LINE=""
    DIMS=$(file -b "$LOOK_TMP/30.png" | grep -oE '[0-9]+ x [0-9]+' | head -n1 || true)
    if [ -n "$DIMS" ]; then
        RATIO=$(echo "$DIMS" | LC_ALL=C awk '{ printf "%.6f", $1 / $3 }')
        ASPECT_LINE="aspect: $RATIO $RATIO; aspect_preference: NONE;"
    fi

    cat > "$LOOK_TMP/bg.edc" << EOF
images { image: "30.png" LOSSY 95; }
collections {
   group { name: "e/desktop/background";
      data { item: "style" "4"; item: "noanimation" "1"; }
      parts {
         part { name: "bg"; type: IMAGE; mouse_events: 0;
            description { state: "default" 0.0;
               $ASPECT_LINE
               image { normal: "30.png"; scale_hint: STATIC; }
            }
         }
      }
   }
}
EOF
    if edje_cc -id "$LOOK_TMP" "$LOOK_TMP/bg.edc" "$LOOK_TMP/bg.edj" >/dev/null 2>&1; then
        sudo install -Dm644 "$LOOK_TMP/bg.edj" "$WALLPAPER_EDJ"
        BG_OK=1
    else
        echo "==> Aviso: edje_cc no pudo generar el fondo .edj; se mantiene el fondo por defecto."
    fi
else
    echo "==> Aviso: no se pudo descargar el fondo de pantalla."
fi

# ---------- 7.4 Configuración por defecto de Enlightenment ----------
echo "==> Guardando la configuración de apariencia en /etc/linuxera-look.conf..."
CONF_THEME=""
CONF_BG=""
if [ "$THEME_OK" -eq 1 ]; then CONF_THEME="$E_THEME_FILE"; fi
if [ "$BG_OK" -eq 1 ]; then CONF_BG="$WALLPAPER_EDJ"; fi

sudo tee /etc/linuxera-look.conf > /dev/null << EOF
# Apariencia por defecto de Enlightenment - COMUNIDAD LINUXERA
# Usado por /usr/local/bin/linuxera-e-look (vacío = no se modifica)
E_THEME="$CONF_THEME"
ICON_THEME="$ICON_THEME"
WALLPAPER_EDJ="$CONF_BG"
EOF

echo "==> Instalando la herramienta linuxera-e-look..."
sudo tee /usr/local/bin/linuxera-e-look > /dev/null << 'HELPER_EOF'
#!/bin/bash
# linuxera-e-look - COMUNIDAD LINUXERA
# Aplica tema, iconos (habilitados para Enlightenment) y fondo por defecto.
#   linuxera-e-look          -> perfiles del sistema (como root; lo usa el hook de pacman)
#   linuxera-e-look --user   -> configuración del usuario actual (~/.e/e), con Enlightenment cerrado
set -uo pipefail

CONF=/etc/linuxera-look.conf
log() { echo "==> [linuxera-e-look] $*"; }

[ -r "$CONF" ] || { log "No existe $CONF"; exit 1; }
# shellcheck source=/dev/null
. "$CONF"
command -v eet > /dev/null 2>&1 || { log "Falta el comando eet (paquete efl)."; exit 1; }

# Fija el valor de 'value "clave" tipo: valor;' en el bloque principal E_Config.
# Si la clave ya existe se respeta su tipo; si no existe se agrega (salvo modo "solo-si-existe").
set_value() {
    local src=$1 key=$2 type=$3 val=$4 mode=${5:-} valtxt tmp
    if [ "$type" = "string" ]; then valtxt="\"$val\""; else valtxt="$val"; fi
    tmp=$(mktemp) || return 1
    if grep -qF "value \"$key\" " "$src"; then
        awk -v pat="value \"$key\" " -v vt="$valtxt" '
            index($0, pat) { sub(/:[ \t].*;[ \t]*$/, ": " vt ";") }
            { print }' "$src" > "$tmp"
    elif [ "$mode" = "solo-si-existe" ]; then
        rm -f "$tmp"; return 0
    else
        awk -v line="  value \"$key\" $type: $valtxt;" '
            !done && /^group "E_Config" struct/ { print; print line; done = 1; next }
            { print }' "$src" > "$tmp"
    fi
    mv "$tmp" "$src"
}

# Fija el tema principal (entrada E_Config_Theme con category "theme")
set_theme() {
    local src=$1 theme=$2 tmp rc block
    tmp=$(mktemp) || return 1
    awk -v theme="$theme" '
        function flush(   i) {
            for (i = 1; i <= n; i++) {
                if (is_theme && buf[i] ~ /value "file" string:/)
                    sub(/string: ".*";/, "string: \"" theme "\";", buf[i])
                print buf[i]
            }
            n = 0; inblk = 0; is_theme = 0
        }
        /group "E_Config_Theme" struct/ { inblk = 1; n = 0 }
        inblk {
            buf[++n] = $0
            if ($0 ~ /value "category" string: "theme";/) { is_theme = 1; found = 1 }
            if ($0 ~ /^[ \t]*}[ \t]*$/) flush()
            next
        }
        { print }
        END { if (n) flush(); exit (found ? 0 : 3) }' "$src" > "$tmp"
    rc=$?
    if [ "$rc" -eq 3 ]; then
        block='group "E_Config_Theme" struct {\n      value "category" string: "theme";\n      value "file" string: "'"$theme"'";\n    }'
        if grep -q 'group "themes" list' "$tmp"; then
            awk -v b="    $block" '!done && /group "themes" list/ { print; print b; done = 1; next } { print }' "$tmp" > "$tmp.2"
        else
            awk -v b="  group \"themes\" list {\n    $block\n  }" '!done && /^group "E_Config" struct/ { print; print b; done = 1; next } { print }' "$tmp" > "$tmp.2"
        fi
        mv "$tmp.2" "$tmp"
        rc=0
    fi
    if [ "$rc" -eq 0 ]; then mv "$tmp" "$src"; else rm -f "$tmp"; return 1; fi
}

patch_cfg() {
    local cfg=$1 work ok=1
    work=$(mktemp -d) || return 1
    if ! eet -d "$cfg" config "$work/e.src" > /dev/null 2>&1; then
        log "No se pudo decodificar $cfg"; rm -rf "$work"; return 1
    fi
    if [ -n "${ICON_THEME:-}" ]; then
        set_value "$work/e.src" icon_theme string "$ICON_THEME" || ok=0
        # "Habilitar tema de iconos para Enlightenment"
        set_value "$work/e.src" icon_theme_overrides uchar 1 || ok=0
        # Pasar el mismo tema de iconos a las aplicaciones GTK vía xsettings
        set_value "$work/e.src" xsettings.match_e17_icon_theme uchar 1 solo-si-existe || ok=0
    fi
    if [ -n "${WALLPAPER_EDJ:-}" ] && [ -f "$WALLPAPER_EDJ" ]; then
        set_value "$work/e.src" desktop_default_background string "$WALLPAPER_EDJ" || ok=0
    fi
    if [ -n "${E_THEME:-}" ]; then
        set_theme "$work/e.src" "$E_THEME" || ok=0
    fi
    if [ "$ok" -ne 1 ]; then
        log "Error editando $cfg (se deja sin cambios)"; rm -rf "$work"; return 1
    fi
    cp "$cfg" "$work/e.cfg"
    if ! eet -e "$work/e.cfg" config "$work/e.src" 1 > /dev/null 2>&1 \
       || ! eet -d "$work/e.cfg" config "$work/check.src" > /dev/null 2>&1; then
        log "Error al recodificar $cfg (se deja sin cambios)"; rm -rf "$work"; return 1
    fi
    [ -f "$cfg.linuxera.bak" ] || cp -p "$cfg" "$cfg.linuxera.bak"
    cat "$work/e.cfg" > "$cfg"
    rm -rf "$work"
}

if [ "${1:-}" = "--user" ]; then
    BASE="$HOME/.e/e/config"
    if pgrep -u "$(id -u)" -x enlightenment > /dev/null 2>&1; then
        log "Enlightenment está en ejecución: cerrá la sesión y ejecutá 'linuxera-e-look --user' desde una TTY."
        exit 1
    fi
else
    [ "$(id -u)" -eq 0 ] || { log "Ejecutalo como root, o con --user para tu usuario."; exit 1; }
    BASE="/usr/share/enlightenment/data/config"
fi

[ -d "$BASE" ] || { log "No existe $BASE; nada que hacer."; exit 0; }

rc=0
n=0
while IFS= read -r -d '' cfg; do
    n=$((n + 1))
    if patch_cfg "$cfg"; then log "Aplicado: $cfg"; else rc=1; fi
done < <(find "$BASE" -mindepth 2 -maxdepth 2 -name e.cfg -print0)
[ "$n" -gt 0 ] || log "No se encontraron perfiles en $BASE."
exit "$rc"
HELPER_EOF
sudo chmod 755 /usr/local/bin/linuxera-e-look

echo "==> Instalando hook de pacman para conservar la apariencia tras actualizar Enlightenment..."
sudo mkdir -p /etc/pacman.d/hooks
sudo tee /etc/pacman.d/hooks/linuxera-e-look.hook > /dev/null << 'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = enlightenment

[Action]
Description = Aplicando tema, iconos y fondo de COMUNIDAD LINUXERA a Enlightenment...
When = PostTransaction
Exec = /usr/local/bin/linuxera-e-look
EOF

echo "==> Aplicando la apariencia a los perfiles de Enlightenment del sistema..."
sudo /usr/local/bin/linuxera-e-look || echo "==> Aviso: no se pudo aplicar a todos los perfiles del sistema."

# Si el usuario ya había iniciado Enlightenment antes, también actualizamos su configuración
if [ -d "$USER_HOME/.e/e/config" ]; then
    echo "==> Aplicando la apariencia a la configuración existente de $REAL_USER..."
    sudo -u "$REAL_USER" -H /usr/local/bin/linuxera-e-look --user \
        || echo "==> Aviso: no se pudo aplicar a la configuración de $REAL_USER."
fi

# ---------- 7.5 Iconos para aplicaciones GTK ----------
echo "==> Configurando $ICON_THEME para aplicaciones GTK 3 y GTK 4..."
REAL_GROUP=$(id -gn "$REAL_USER")
for GTK_VER in 3.0 4.0; do
    # Usuario actual
    GTK_FILE="$USER_HOME/.config/gtk-$GTK_VER/settings.ini"
    GTK_TMP=$(mktemp)
    if [ -f "$GTK_FILE" ]; then cat "$GTK_FILE" > "$GTK_TMP"; fi
    ini_set "$GTK_TMP" Settings gtk-icon-theme-name "$ICON_THEME"
    sudo -u "$REAL_USER" mkdir -p "$(dirname "$GTK_FILE")"
    sudo install -m644 -o "$REAL_USER" -g "$REAL_GROUP" "$GTK_TMP" "$GTK_FILE"

    # Usuarios nuevos (/etc/skel)
    SKEL_FILE="/etc/skel/.config/gtk-$GTK_VER/settings.ini"
    : > "$GTK_TMP"
    if [ -f "$SKEL_FILE" ]; then cat "$SKEL_FILE" > "$GTK_TMP"; fi
    ini_set "$GTK_TMP" Settings gtk-icon-theme-name "$ICON_THEME"
    sudo install -Dm644 "$GTK_TMP" "$SKEL_FILE"
    rm -f "$GTK_TMP"
done

# ---------- 7.6 Pantalla de inicio de sesión (Slick Greeter) ----------
echo "==> Aplicando fondo e iconos a la pantalla de inicio de sesión..."
GREETER_CONF="/etc/lightdm/slick-greeter.conf"
GREETER_TMP=$(mktemp)
if [ -f "$GREETER_CONF" ]; then cat "$GREETER_CONF" > "$GREETER_TMP"; fi
if [ -f "$WALLPAPER_PNG" ]; then
    ini_set "$GREETER_TMP" Greeter background "$WALLPAPER_PNG"
    ini_set "$GREETER_TMP" Greeter draw-user-backgrounds false
fi
ini_set "$GREETER_TMP" Greeter icon-theme-name "$ICON_THEME"
sudo install -Dm644 "$GREETER_TMP" "$GREETER_CONF"
rm -f "$GREETER_TMP"

rm -rf "$LOOK_TMP"


# ==========================================
# 8. LIMPIEZA Y REINICIO
# ==========================================
# Nota: NO se redefine USER_HOME con $HOME. Con sudo, $HOME puede apuntar a
# /root; usamos el USER_HOME calculado al inicio a partir de REAL_USER.

echo "==> Eliminando dependencias huérfanas (p. ej. dependencias de compilación de yay)..."
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    # shellcheck disable=SC2086
    sudo pacman -Rns --noconfirm $ORPHANS || echo "==> Aviso: no se pudieron quitar algunos huérfanos, se continúa."
else
    echo "==> No hay paquetes huérfanos."
fi

echo "==> Limpiando caché de pacman (se conservan los paquetes instalados)..."
sudo pacman -Sc --noconfirm >/dev/null || true

echo "==> Limpiando caché de compilación de yay..."
rm -rf "$USER_HOME/.cache/yay" 2>/dev/null || true

SCRIPT_REPO_DIR="$USER_HOME/LinuxScripts"
if [ -d "$SCRIPT_REPO_DIR" ]; then
    echo "==> Limpiando carpeta del script ($SCRIPT_REPO_DIR)..."
    # Salimos de la carpeta antes de borrarla, por si el script se ejecuta desde ahí
    cd "$USER_HOME"
    rm -rf "$SCRIPT_REPO_DIR"
fi

# Resumen final (coincide con lo que realmente instala este script)
cat << 'EOF'
======================================================
 Instalación y configuración completadas con éxito.
 Display manager:       LightDM + Slick Greeter
 Entorno de escritorio: Enlightenment
 Terminal:              Terminology
 Tema:                  Dimensions (Enlightenment + Elementary)
 Iconos:                Yaru-blue-dark (también en Enlightenment)
 Fondo de pantalla:     archlinux-wallpapers 30.png
 Gestor de archivos:    EFM (integrado en Enlightenment)
 Red:                   ConnMan
 Gestores de paquetes:  pacman, yay, shelly
 Repositorios activos:  kiro (nemesis_repo) + chaotic-aur

 SSSS   III   N   N  EEEEE  RRRR    GGG    III    AAA
S        I    NN  N  E      R   R  G   G    I    A   A
S        I    N N N  E      R   R  G        I    A   A
 SSS     I    N N N  EEEE   RRRR   G GGG    I    AAAAA
    S    I    N  NN  E      R R    G   G    I    A   A
    S    I    N   N  E      R  R   G   G    I    A   A
SSSS    III   N   N  EEEEE  R   R   GGG    III   A   A
======================================================
            COMUNIDAD    LINUXERA
======================================================
EOF

# Si no hay terminal interactiva (stdin redirigido), no reiniciamos solos
if [ -t 0 ]; then
    read -r -t 15 -p "¿Reiniciar el sistema ahora? (S/n, reinicia solo en 15s): " respuesta || respuesta="s"
    echo
else
    respuesta="n"
fi

case "${respuesta,,}" in
    s|si|sí|"")
        echo "==> Sincronizando discos y reiniciando..."
        sync
        sudo systemctl reboot
        ;;
    *)
        echo "==> Reinicio cancelado. Recordá reiniciar manualmente para aplicar los cambios."
        ;;
esac
