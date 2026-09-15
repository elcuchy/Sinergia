#!/bin/bash

# Exit on error (si un comando falla, el script se detiene por seguridad)
set -e

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
# 1.1 CONFIGURACIÓN DEL REPOSITORIO MULTILIB
# ==========================================
echo "==> Verificando repositorio multilib..."

if grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "==> El repositorio multilib ya está habilitado."
elif grep -q "^#\[multilib\]" /etc/pacman.conf; then
    echo "==> Habilitando repositorio multilib (estaba comentado)..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
else
    echo "==> Agregando repositorio multilib (no existía en el archivo)..."
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF'
fi

sudo pacman -Sy


# ==========================================
# 2. CONFIGURACIÓN DEL REPOSITORIO NEMESIS_REPO (KIRO)
# ==========================================
echo "==> Configurando el repositorio nemesis_repo..."

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
sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keys.openpgp.org

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
sudo pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com:443
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
echo "==> Instalando XFCE, aplicaciones, dependencias y paquetes del sistema..."
sudo pacman -S --noconfirm --needed \
  xorg-server \
  xorg-apps \
  xfce4 \
  xfce4-goodies \
  xfce4-panel-profiles \
  xfce4-whiskermenu-plugin \
  xfce4-docklike-plugin \
  xfce4-windowck-plugin \
  xfce4-places-plugin \
  plank \
  python-gobject \
  dbus \
  lightdm \
  lightdm-gtk-greeter \
  pipewire-pulse \
  wireplumber \
  pavucontrol \
  network-manager-applet \
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
  conky \
  wireless_tools \
  playerctl \
  jq \
  nano \
  ulauncher \
  audacious \
  pamac-aur \
  xdg-user-dirs \
  xdg-user-dirs-gtk \
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
  mousepad \
  xfce4-taskmanager \
  xfce4-screenshooter \
  obs-studio \
  audacity \
  ardour \
  kdenlive \
  ventoy \
  papirus-icon-theme \
  mint-l-icons \
  mint-x-icons \
  mint-y-icons \
  mate-icon-theme-faenza \
  rustdesk-bin \
  gnome-boxes \
  amber-theme-git \
  arc-gtk-theme \
  colloid-gtk-theme-git \
  graphite-gtk-theme-black-normal-git \
  os-prober

# NOTA: xfce4-whiskermenu-plugin, xfce4-docklike-plugin y xfce4-windowck-plugin
# son requeridos por varios de los layouts que trae xfce4-panel-profiles
# (Redmond, Redmond 7, Cupertino, Unity). Sin ellos, esos perfiles cargan
# incompletos o directamente fallan al aplicarse. "plank" se agrega porque
# el layout Cupertino (estilo macOS) espera un dock tipo plank disponible.
# "xdg-user-dirs" y "xdg-user-dirs-gtk" se agregan porque sin ellos el
# $HOME del usuario queda sin las carpetas estándar (Documentos, Imágenes,
# Descargas, Música, Vídeos, Escritorio, Público, Plantillas): ese paquete
# trae el autostart que las genera en el primer login gráfico. Se agrega
# además un paso explícito más abajo para generarlas ya mismo, sin
# depender de ese primer login.

# ==========================================
# 5. INSTALACIÓN DE YAY Y PAQUETES AUR
# ==========================================
echo "==> Asegurando base-devel e instalando YAY..."
sudo pacman -S --needed base-devel git --noconfirm

BUILD_DIR=$(mktemp -d)
sudo chown -R "$REAL_USER:$REAL_USER" "$BUILD_DIR"

sudo -u "$REAL_USER" bash -c "
  git clone https://aur.archlinux.org/yay.git '$BUILD_DIR/yay'
  cd '$BUILD_DIR/yay'
  makepkg -si --noconfirm
"
rm -rf "$BUILD_DIR"

echo "==> Instalando paquetes AUR adicionales..."
sudo -u "$REAL_USER" yay -S --needed --noconfirm \
  stacer-bin \
  sinergia-dd-burner \
  aimp \
  iptvnator-bin \
  yaru-colors-icon-theme \
  fetch-git


# ==========================================
# 6. CONFIGURACIÓN DE APARIENCIA Y ENTORNO
# ==========================================
echo "==> Personalizando apariencia (Graphite-Dark, GreyStone, Transparencia)..."

# Ícono GreyStone (Default Edition), bajado directo del repo del autor.
# Requiere Papirus (ya instalado en la sección 4). El nombre real de la
# carpeta del tema dentro del .tar.gz no está confirmado de antemano, así
# que se detecta buscando su index.theme en vez de asumir un nombre fijo
# — si algo falla en el camino, se cae de vuelta a Yaru-Teal (ya instalado
# y configurado en un paso anterior) en vez de dejar todo roto.
GREYSTONE_URL="https://codeberg.org/StormRosenaa/GreyStone/raw/branch/main/GreyStone.tar.gz"
GREYSTONE_EXTRACT_DIR="/tmp/greystone_extract"
ICON_THEME_NAME="Yaru-Teal"

if ! command -v curl >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm curl
fi

mkdir -p "$GREYSTONE_EXTRACT_DIR"
if curl -fsSL "$GREYSTONE_URL" -o /tmp/GreyStone.tar.gz; then
    if tar -xzf /tmp/GreyStone.tar.gz -C "$GREYSTONE_EXTRACT_DIR" 2>/dev/null; then
        DETECTED_THEME_DIR=$(find "$GREYSTONE_EXTRACT_DIR" -name "index.theme" -exec dirname {} \; | head -n1)
        if [ -n "$DETECTED_THEME_DIR" ]; then
            ICON_THEME_NAME=$(basename "$DETECTED_THEME_DIR")
            sudo cp -r "$DETECTED_THEME_DIR" /usr/share/icons/
            sudo gtk-update-icon-cache -f "/usr/share/icons/$ICON_THEME_NAME" 2>/dev/null
            echo "==> Tema de íconos GreyStone instalado como '$ICON_THEME_NAME'"
        else
            echo "==> Advertencia: no se encontró index.theme dentro del paquete de GreyStone; se mantiene Yaru-Teal."
        fi
    else
        echo "==> Advertencia: no se pudo descomprimir GreyStone.tar.gz; se mantiene Yaru-Teal."
    fi
else
    echo "==> Advertencia: no se pudo descargar GreyStone; se mantiene Yaru-Teal."
fi
rm -f /tmp/GreyStone.tar.gz
rm -rf "$GREYSTONE_EXTRACT_DIR"

apply_user_configs() {
    local TARGET_DIR="$1"
    local USER_NAME="$2"

    # Directorios base
    sudo mkdir -p "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml"
    sudo mkdir -p "$TARGET_DIR/xfce4/terminal"
    sudo mkdir -p "$TARGET_DIR/gtk-3.0"
    sudo mkdir -p "$TARGET_DIR/gtk-4.0"

    # 1. Configuración del Tema y los Íconos en XFCE
    sudo tee "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Graphite-Dark"/>
    <property name="IconThemeName" type="string" value="$ICON_THEME_NAME"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CursorThemeName" type="string" value="Yaru"/>
  </property>
</channel>
EOF

    # 2. Transparencia por defecto en XFCE Terminal
    sudo tee "$TARGET_DIR/xfce4/terminal/terminalrc" > /dev/null << 'EOF'
[Configuration]
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.85
EOF

    # 3. Extender tema oscuro a apps GTK3/GTK4
    sudo tee "$TARGET_DIR/gtk-3.0/settings.ini" > /dev/null << EOF
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=$ICON_THEME_NAME
gtk-application-prefer-dark-theme=1
EOF

    sudo tee "$TARGET_DIR/gtk-4.0/settings.ini" > /dev/null << EOF
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=$ICON_THEME_NAME
gtk-application-prefer-dark-theme=1
EOF

    # Ajustar permisos de la estructura
    if [ "$USER_NAME" != "root" ]; then
        sudo chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR"
    fi
}

# Aplicar a /etc/skel y al usuario actual
apply_user_configs "/etc/skel/.config" "root"
apply_user_configs "$USER_HOME/.config" "$REAL_USER"

# Configuración del tema para aplicaciones QT con privilegios elevados
if ! grep -q "QT_QPA_PLATFORMTHEME" /etc/environment; then
    echo "QT_QPA_PLATFORMTHEME=qt5ct" | sudo tee -a /etc/environment
fi

# ==========================================
# 6.1 GENERACIÓN DE CARPETAS DE USUARIO (XDG)
# ==========================================
# xdg-user-dirs normalmente crea Documentos, Imágenes, Descargas, Música,
# Vídeos, Escritorio, Público y Plantillas vía un autostart que corre en
# el primer login gráfico (/etc/xdg/autostart/xdg-user-dirs.desktop).
# Lo forzamos acá para que las carpetas ya existan sin depender de ese
# primer login, tanto para el usuario real como para /etc/skel (así los
# futuros usuarios del sistema también las heredan al crearse).
echo "==> Generando carpetas de usuario estándar (Documentos, Imágenes, etc.)..."

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    sudo -u "$REAL_USER" env HOME="$USER_HOME" \
        XDG_CONFIG_HOME="$USER_HOME/.config" \
        xdg-user-dirs-update || \
        echo "==> Advertencia: xdg-user-dirs-update falló para $REAL_USER; las carpetas se crearán en el próximo login."

    # También lo corremos contra /etc/skel para que usuarios creados
    # después de este script hereden la config de carpetas ya definida.
    sudo env HOME="/etc/skel" XDG_CONFIG_HOME="/etc/skel/.config" \
        xdg-user-dirs-update || true

    sudo chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config" 2>/dev/null || true
else
    echo "==> Advertencia: xdg-user-dirs-update no está disponible; revisá que el paquete xdg-user-dirs se haya instalado."
fi

# ==========================================
# 7. APLICACIÓN DEL PERFIL OPENSUSE LEAP 15.X
# ==========================================
echo "==> Cargando el perfil openSUSE Leap 15.x en el usuario $REAL_USER..."

# El nombre exacto de archivo puede variar según cómo esté empaquetado
# (mayúsculas, espacios, versión). Confirmado en este sistema como
# "openSUSE Leap 15.x.tar.bz2"; se agregan variantes razonables como
# respaldo, sin garantía de que existan (no verificadas).
LAYOUT_FILE=""
for candidate in \
    "/usr/share/xfce4-panel-profiles/layouts/openSUSE Leap 15.x.tar.bz2" \
    "/usr/share/xfce4-panel-profiles/layouts/opensuse-leap-15.x.tar.bz2" \
    "/usr/share/xfce4-panel-profiles/layouts/OpenSUSE Leap 15.x.tar.bz2"; do
    if [ -f "$candidate" ]; then
        LAYOUT_FILE="$candidate"
        break
    fi
done

# Ícono del lanzador de aplicaciones (whisker menu). Usamos la ruta
# absoluta al archivo en vez del nombre lógico "archlinux-logo", porque
# el nombre lógico depende de que el tema de íconos activo lo tenga
# indexado con ese nombre exacto — cosa que no pasaba en este sistema.
LAUNCHER_ICON="/usr/share/pixmaps/archlinux-logo.svg"
if [ ! -f "$LAUNCHER_ICON" ]; then
    echo "==> Advertencia: no se encontró $LAUNCHER_ICON. Buscando alternativas..."
    ALT_ICON=$(find /usr/share/pixmaps /usr/share/icons -iname "archlinux-logo*" 2>/dev/null | head -n1)
    if [ -n "$ALT_ICON" ]; then
        echo "==> Usando en su lugar: $ALT_ICON"
        LAUNCHER_ICON="$ALT_ICON"
    else
        echo "==> No se encontró ningún archivo archlinux-logo.*. Se mantiene $LAUNCHER_ICON de todas formas."
    fi
fi

# Función que fija el icono del whisker menu (button-icon) en el
# xfce4-panel.xml ya extraído, para el plugin cuyo tipo sea "whiskermenu".
# Solo se usa para /etc/skel (usuarios futuros), donde no hay una sesión
# D-Bus viva a la que aplicarle el cambio: ahí no queda otra que editar
# el XML directamente. Busca el archivo con find en vez de asumir una
# ruta fija, para no fallar en silencio si la estructura interna del
# .tar.bz2 del layout no es la esperada.
set_whisker_icon_file() {
    local BASE_DIR="$1"
    local PANEL_XML
    PANEL_XML=$(sudo find "$BASE_DIR" -type f -name "xfce4-panel.xml" 2>/dev/null | head -n1)
    if [ -n "$PANEL_XML" ] && [ -f "$PANEL_XML" ]; then
        sudo python3 - "$PANEL_XML" "$LAUNCHER_ICON" << 'PYEOF'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
icon_path = sys.argv[2]
tree = ET.parse(path)
root = tree.getroot()

plugins = root.find(".//property[@name='plugins']")
if plugins is not None:
    for plugin in plugins.findall("property"):
        if plugin.get("name", "").startswith("plugin-") and plugin.get("value") == "whiskermenu":
            icon_prop = None
            for child in plugin.findall("property"):
                if child.get("name") == "button-icon":
                    icon_prop = child
                    break
            if icon_prop is None:
                icon_prop = ET.SubElement(plugin, "property")
                icon_prop.set("name", "button-icon")
                icon_prop.set("type", "string")
            icon_prop.set("value", icon_path)

tree.write(path, encoding="UTF-8", xml_declaration=True)
PYEOF
    else
        echo "==> Advertencia: no se encontró xfce4-panel.xml bajo $BASE_DIR; no se pudo fijar el ícono ahí."
    fi
}

# Para el usuario actual (en vivo) hacemos TODO en una sola sesión D-Bus:
# cargar el perfil openSUSE Leap 15.x y fijar el ícono del whiskermenu, en ese
# orden, dentro del mismo proceso. Antes esto estaba repartido en dos
# invocaciones separadas de dbus-run-session (una para cargar el perfil,
# otra para el ícono) con una extracción de tar en el medio que volvía a
# pisar el XML con el valor original — cada sesión D-Bus nueva arranca su
# propio xfconfd, y esa mezcla de sesiones y reescrituras de archivo era
# una condición de carrera real. Al hacerlo todo en una sola sesión
# secuencial, no hay ventana donde algo más pueda pisar el cambio.
apply_profile_and_icon_live() {
    local LOAD_CMD=""
    if [ -n "$LAYOUT_FILE" ]; then
        LOAD_CMD="xfce4-panel-profiles load \"\$LAYOUT_PATH\"; sleep 2;"
    fi
    sudo -u "$REAL_USER" env LAYOUT_PATH="$LAYOUT_FILE" ICON_PATH="$LAUNCHER_ICON" \
        dbus-run-session bash -c "
            $LOAD_CMD
            PLUGIN_IDS=\$(xfconf-query -c xfce4-panel -p /plugins -l -v 2>/dev/null \
                | awk '\$2==\"whiskermenu\" {print \$1}' \
                | grep -oE '[0-9]+\$')
            for id in \$PLUGIN_IDS; do
                xfconf-query -c xfce4-panel -p \"/plugins/plugin-\${id}/button-icon\" \
                    -n -t string -s \"\$ICON_PATH\" 2>/dev/null || \
                xfconf-query -c xfce4-panel -p \"/plugins/plugin-\${id}/button-icon\" \
                    -s \"\$ICON_PATH\" 2>/dev/null
            done
        " || true
}

if [ -n "$LAYOUT_FILE" ]; then
    apply_profile_and_icon_live

    # Extraer el layout en /etc/skel para que futuros usuarios lo hereden,
    # y fijar ahí el ícono editando el XML directamente (no hay sesión
    # D-Bus viva para un usuario que todavía no existe).
    sudo mkdir -p /etc/skel/.config/xfce4
    sudo tar -xjf "$LAYOUT_FILE" -C /etc/skel/.config/xfce4/ --strip-components=1 2>/dev/null || true
    set_whisker_icon_file "/etc/skel/.config"
else
    echo "==> Advertencia: No se encontró el archivo de layout openSUSE Leap 15.x. Verificá el nombre real con:"
    echo "    ls /usr/share/xfce4-panel-profiles/layouts/"
    # Igual intentamos fijar el ícono por si el panel por defecto ya
    # trae un plugin whiskermenu configurado.
    apply_profile_and_icon_live
fi

# Ajustar permisos finales
sudo chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config"


# ==========================================
# 8. CONFIGURACIÓN DEL FONDO DE PANTALLA
# ==========================================
echo "==> Descargando el fondo de pantalla..."

WALLPAPER_URL="https://raw.githubusercontent.com/f4dzN/archlinux-wallpapers/main/wallpapers/18.png"
WALLPAPER_DIR="/usr/share/backgrounds/archlinux-wallpapers"
WALLPAPER_FILE="$WALLPAPER_DIR/18.png"

# curl no viene en una instalación base de Arch por defecto; lo instalamos
# si hace falta, sin tocar la lista grande de paquetes de la sección 4.
if ! command -v curl >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm curl
fi

sudo mkdir -p "$WALLPAPER_DIR"
if sudo curl -fsSL "$WALLPAPER_URL" -o "$WALLPAPER_FILE"; then
    sudo chmod 644 "$WALLPAPER_FILE"
    echo "==> Fondo de pantalla descargado en $WALLPAPER_FILE"
else
    echo "==> Advertencia: no se pudo descargar el fondo de pantalla desde $WALLPAPER_URL"
fi

# No podemos saber el nombre real del monitor (eDP-1, HDMI-1, DP-1, etc.)
# desde este script: corre antes del primer login gráfico, sin servidor X
# activo, en una PC que puede ser cualquiera. En vez de asumir un nombre
# fijo (que solo funcionaría en la máquina donde se probó), dejamos una
# tarea de autostart que corre UNA SOLA VEZ en el primer login real de
# cualquier usuario en cualquier PC — momento en el que xrandr ya puede
# leer el hardware real — y se autoelimina después de aplicar el fondo.
if [ -f "$WALLPAPER_FILE" ]; then
    echo "==> Instalando tarea de primer-login para fijar el fondo según el monitor real..."

    sudo tee /usr/local/bin/set-wallpaper-once.sh > /dev/null << EOF
#!/bin/bash
# Se ejecuta una sola vez en el primer login (ver autostart). Detecta los
# monitores reales vía xrandr (ya disponibles porque corre dentro de la
# sesión gráfica) y fija el fondo para cada uno. Al terminar, se borra a
# sí mismo junto con la entrada de autostart que lo lanzó.

WALLPAPER="$WALLPAPER_FILE"
sleep 5

if [ -f "\$WALLPAPER" ]; then
    MONITORS=\$(xrandr --listmonitors 2>/dev/null | awk 'NR>1 {print \$NF}')
    if [ -z "\$MONITORS" ]; then
        MONITORS="monitor0"
    fi
    for m in \$MONITORS; do
        xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor\${m}/workspace0/last-image" \
            -n -t string -s "\$WALLPAPER" 2>/dev/null || \
        xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor\${m}/workspace0/last-image" \
            -s "\$WALLPAPER" 2>/dev/null
        xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor\${m}/workspace0/image-style" \
            -n -t int -s 5 2>/dev/null
    done
fi

rm -f "\$HOME/.config/autostart/set-wallpaper-once.desktop"
rm -f "\$0"
EOF
    sudo chmod 755 /usr/local/bin/set-wallpaper-once.sh

    write_wallpaper_autostart() {
        local TARGET_DIR="$1"
        local USER_NAME="$2"
        sudo mkdir -p "$TARGET_DIR/autostart"
        sudo tee "$TARGET_DIR/autostart/set-wallpaper-once.desktop" > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/set-wallpaper-once.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Name=Fijar fondo de pantalla (primera vez)
Comment=Tarea única que fija el fondo de pantalla según el monitor detectado y se autoelimina
EOF
        if [ "$USER_NAME" != "root" ]; then
            sudo chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR/autostart"
        fi
    }

    write_wallpaper_autostart "/etc/skel/.config" "root"
    write_wallpaper_autostart "$USER_HOME/.config" "$REAL_USER"
fi





# ==========================================
# 9. INSTALACIÓN DEL TEMA CONKY NORDCORE (NORD GREEN/FROST)
# ==========================================
# Reemplaza a la vieja sección 9 (Conky Electra). Si tenías Electra
# instalado de una corrida anterior del script, este bloque no lo
# desinstala solo; borrá manualmente ~/.config/conky/Electra y
# ~/.config/autostart/electra-conky.desktop si ya corriste esa versión
# antes, para que no quede compitiendo por la pantalla.
echo "==> Instalando el tema Conky Nordcore..."

# El tema viene embebido en base64 (subido como .zip), corregido antes
# de empaquetarlo:
#  - se descartó accu_weather/ (config huérfana de MX-Linux sin uso real,
#    apuntaba a AccuWeather RSS clásico, dado de baja hace años)
#  - weather/weather_raw ya no son el dump estático de Pristina-2013 del
#    zip original: se agregó scripts/update_weather.sh, que trae clima
#    real vía wttr.in (sin API key, geolocalización automática por IP)
#  - conkyrc2core quedó con placeholders __IFACE_*__ en vez de
#    ens33/eth1/wlan0/wlan1 hardcodeados; este script los reemplaza más
#    abajo por las interfaces reales de la máquina
#  - se quitaron las referencias a las fuentes "ConkyWeather" y
#    "caviar dreams" (no venían en el zip); el ícono de clima ahora es
#    el emoji que trae wttr.in, no depende de una fuente de íconos aparte
#  - start_conky.sh.desktop original tenía una ruta hardcodeada de otro
#    usuario (/home/linuxscoop/...); se reemplaza por un autostart con
#    ruta dinámica, igual que se corrigió para Electra
NORDCORE_B64_FILE="/tmp/nordcore_theme.b64"
NORDCORE_ZIP="/tmp/nordcore.zip"
NORDCORE_EXTRACT_DIR="/tmp/nordcore_extract"

cat > "$NORDCORE_B64_FILE" << 'NORDCORE_B64_EOF'
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
NORDCORE_B64_EOF

base64 -d "$NORDCORE_B64_FILE" > "$NORDCORE_ZIP" 2>/dev/null
rm -f "$NORDCORE_B64_FILE"

if ! command -v unzip >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm unzip
fi

if [ -f "$NORDCORE_ZIP" ]; then
    rm -rf "$NORDCORE_EXTRACT_DIR"
    mkdir -p "$NORDCORE_EXTRACT_DIR"
    if unzip -o -q "$NORDCORE_ZIP" -d "$NORDCORE_EXTRACT_DIR"; then

        # Detectar interfaces de red reales de la máquina en vez de
        # confiar en los nombres que traía el tema original (ens33,
        # eth1, wlan0, wlan1). Se clasifican por si tienen carpeta
        # "wireless" en sysfs, forma estándar de distinguir WiFi de
        # cableada en Linux.
        WIRED_IFACES=()
        WIFI_IFACES=()
        for iface_path in /sys/class/net/*; do
            iface=$(basename "$iface_path")
            [ "$iface" = "lo" ] && continue
            if [ -d "$iface_path/wireless" ]; then
                WIFI_IFACES+=("$iface")
            else
                WIRED_IFACES+=("$iface")
            fi
        done

        # Se completan los 4 slots del tema con lo detectado; si sobra
        # algún slot sin interfaz real, se deja un nombre que nunca va
        # a existir para que los ${if_up} del .conf lo salteen sin
        # romper nada.
        IFACE_WIRED1="${WIRED_IFACES[0]:-none0}"
        IFACE_WIRED2="${WIRED_IFACES[1]:-none1}"
        IFACE_WIFI1="${WIFI_IFACES[0]:-none2}"
        IFACE_WIFI2="${WIFI_IFACES[1]:-none3}"

        echo "==> Interfaces detectadas para Conky Nordcore: cableadas=[${WIRED_IFACES[*]}] wifi=[${WIFI_IFACES[*]}]"

        sed -i \
            -e "s/__IFACE_WIRED1__/${IFACE_WIRED1}/" \
            -e "s/__IFACE_WIRED2__/${IFACE_WIRED2}/" \
            -e "s/__IFACE_WIFI1__/${IFACE_WIFI1}/" \
            -e "s/__IFACE_WIFI2__/${IFACE_WIFI2}/" \
            "$NORDCORE_EXTRACT_DIR/nordcore/conkyrc2core"

        install_nordcore_theme() {
            local HOME_DIR="$1"
            local USER_NAME="$2"
            sudo mkdir -p "$HOME_DIR/.conky"
            sudo rm -rf "$HOME_DIR/.conky/nordcore"
            sudo cp -r "$NORDCORE_EXTRACT_DIR/nordcore" "$HOME_DIR/.conky/nordcore"
            sudo chmod +x "$HOME_DIR/.conky/nordcore/start_conky.sh"
            sudo chmod +x "$HOME_DIR/.conky/nordcore/scripts/update_weather.sh"
            if [ "$USER_NAME" != "root" ]; then
                sudo chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.conky"
            fi
        }

        install_nordcore_theme "$USER_HOME" "$REAL_USER"
        install_nordcore_theme "/etc/skel" "root"

        # Fuentes del tema: Radio_Space (sí se usa, label ubicación) y
        # AvantGarde_LT_Medium (viene en el zip pero no la referencia
        # nada del .conf ni del .lua; se instala igual, no hace daño).
        sudo mkdir -p /usr/share/fonts/nordcore-conky
        sudo cp "$NORDCORE_EXTRACT_DIR/nordcore/fonts/"*.ttf /usr/share/fonts/nordcore-conky/
        sudo fc-cache -f > /dev/null 2>&1

        # Roboto Light es la única fuente que realmente falta y sí se ve
        # en pantalla (reloj y casi todo el texto): existe como paquete
        # oficial de Arch, no hace falta bundlearla a mano.
        sudo pacman -S --needed --noconfirm ttf-roboto

        # Autostart con ruta dinámica (corrige el /home/linuxscoop/...
        # hardcodeado del start_conky.sh.desktop original del zip).
        write_nordcore_autostart() {
            local TARGET_DIR="$1"
            local USER_NAME="$2"
            sudo mkdir -p "$TARGET_DIR/autostart"
            sudo tee "$TARGET_DIR/autostart/nordcore-conky.desktop" > /dev/null << 'EOF'
[Desktop Entry]
Type=Application
Exec=bash -c "$HOME/.conky/nordcore/start_conky.sh"
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Name=Nordcore Conky
Comment=Inicia el tema Conky Nordcore (Nord green/frost) al iniciar sesión
EOF
            if [ "$USER_NAME" != "root" ]; then
                sudo chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR/autostart"
            fi
        }

        write_nordcore_autostart "$USER_HOME/.config" "$REAL_USER"
        write_nordcore_autostart "/etc/skel/.config" "root"

        echo "==> Tema Conky Nordcore instalado y configurado para iniciar en cada login."
    else
        echo "==> Advertencia: no se pudo descomprimir el tema Conky Nordcore."
    fi
else
    echo "==> Advertencia: no se pudo decodificar el tema Conky Nordcore embebido."
fi

rm -rf "$NORDCORE_EXTRACT_DIR" "$NORDCORE_ZIP"


# ==========================================
# 10. CONFIGURACIÓN DE SYSTEM SERVICES Y GRUB
# ==========================================
echo "==> Configurando LightDM con GTK Greeter..."
sudo sed -i 's/#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
sudo systemctl enable lightdm

echo "==> Configurando GRUB para detectar otros SO..."
if [ -f /etc/default/grub ]; then
    sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi


# ==========================================
# 11. LIMPIEZA Y REINICIO
# ==========================================
rm -rf "$USER_HOME/LinuxScripts"

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Display manager configurado: LightDM (GTK Greeter)"
echo " Entorno de escritorio: XFCE 4 + xfce4-goodies"
echo " Perfil de panel: openSUSE Leap 15.x"
echo " Tema Global: Graphite-Dark"
echo " Icon theme: $ICON_THEME_NAME con ícono de lanzador: $LAUNCHER_ICON"
echo " Fondo de pantalla: $WALLPAPER_FILE"
echo " Conky: Electra (abajo a la derecha)"
echo " XFCE Terminal: transparencia por defecto (BackgroundDarkness=0.85)"
echo " GRUB: os-prober habilitado (detección de otros SO)"
echo "  
 SSSS   III   N   N  EEEEE  RRRR    GGG    III    AAA
S        I    NN  N  E      R   R  G   G    I    A   A
S        I    N N N  E      R   R  G        I    A   A
 SSS     I    N N N  EEEE   RRRR   G GGG    I    AAAAA
    S    I    N  NN  E      R R    G   G    I    A   A
    S    I    N   N  E      R  R   G   G    I    A   A
SSSS    III   N   N  EEEEE  R   R   GGG    III   A   A"
echo "======================================================"
echo "            COMUNIDAD    LINUXERA"
echo "======================================================"

read -t 15 -p "Reiniciar el sistema ahora? (s/N, auto-continúa en 15s): " respuesta || respuesta="s"
case "$respuesta" in
    [sS]|"")
        echo "==> Reiniciando..."
        sudo reboot
        ;;
    *)
        echo "==> Reinicio cancelado. Recordá reiniciar manualmente para aplicar los cambios."
        ;;
esac
