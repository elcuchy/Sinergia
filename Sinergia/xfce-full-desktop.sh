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
  nano \
  ulauncher \
  audacious \
  pamac-aur \
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
echo "==> Personalizando apariencia (Graphite-Dark, Yaru-MATE, Transparencia)..."

apply_user_configs() {
    local TARGET_DIR="$1"
    local USER_NAME="$2"

    # Directorios base
    sudo mkdir -p "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml"
    sudo mkdir -p "$TARGET_DIR/xfce4/terminal"
    sudo mkdir -p "$TARGET_DIR/gtk-3.0"
    sudo mkdir -p "$TARGET_DIR/gtk-4.0"

    # 1. Configuración del Tema y los Íconos en XFCE
    sudo tee "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Graphite-Dark"/>
    <property name="IconThemeName" type="string" value="Yaru-MATE"/>
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
    sudo tee "$TARGET_DIR/gtk-3.0/settings.ini" > /dev/null << 'EOF'
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=Yaru-MATE
gtk-application-prefer-dark-theme=1
EOF

    sudo tee "$TARGET_DIR/gtk-4.0/settings.ini" > /dev/null << 'EOF'
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=Yaru-MATE
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
echo "==> Descargando y configurando el fondo de pantalla..."

WALLPAPER_URL="https://raw.githubusercontent.com/f4dzN/archlinux-wallpapers/main/wallpapers/30.png"
WALLPAPER_DIR="/usr/share/backgrounds/archlinux-wallpapers"
WALLPAPER_FILE="$WALLPAPER_DIR/30.png"

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

if [ -f "$WALLPAPER_FILE" ]; then
    # Función que escribe un xfce4-desktop.xml con una propiedad genérica
    # "monitor0" (fallback estándar para instalaciones de un solo monitor
    # antes del primer login, cuando XFCE todavía no detectó el nombre
    # real del monitor conectado).
    write_wallpaper_config() {
        local TARGET_DIR="$1"
        local USER_NAME="$2"
        sudo mkdir -p "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml"
        sudo tee "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="last-image" type="string" value="$WALLPAPER_FILE"/>
          <property name="image-style" type="int" value="5"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
        if [ "$USER_NAME" != "root" ]; then
            sudo chown -R "$USER_NAME:$USER_NAME" "$TARGET_DIR/xfce4"
        fi
    }

    write_wallpaper_config "/etc/skel/.config" "root"
    write_wallpaper_config "$USER_HOME/.config" "$REAL_USER"

    # Además, intentamos fijarlo en vivo: si ya existe alguna propiedad de
    # fondo real (monitor detectado), la pisamos también, por si el archivo
    # de arriba no alcanza a aplicarse (mismo enfoque que con el ícono del
    # lanzador: todo en una sola sesión D-Bus para evitar condiciones de
    # carrera entre sesiones separadas).
    sudo -u "$REAL_USER" env WALLPAPER_PATH="$WALLPAPER_FILE" dbus-run-session bash -c '
        EXISTING=$(xfconf-query -c xfce4-desktop -l -v 2>/dev/null \
            | awk "/last-image$|image-path$/ {print \$1}")
        for p in $EXISTING; do
            xfconf-query -c xfce4-desktop -p "$p" -s "$WALLPAPER_PATH" 2>/dev/null
        done
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image \
            -n -t string -s "$WALLPAPER_PATH" 2>/dev/null
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/image-style \
            -n -t int -s 5 2>/dev/null
    ' || true
fi


# ==========================================
# 9. CONFIGURACIÓN DE SYSTEM SERVICES Y GRUB
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
# 10. LIMPIEZA Y REINICIO
# ==========================================
rm -rf "$USER_HOME/LinuxScripts"

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Display manager configurado: LightDM (GTK Greeter)"
echo " Entorno de escritorio: XFCE 4 + xfce4-goodies"
echo " Perfil de panel: openSUSE Leap 15.x"
echo " Tema Global: Graphite-Dark"
echo " Icon theme: Yaru-MATE con ícono de lanzador: $LAUNCHER_ICON"
echo " Fondo de pantalla: $WALLPAPER_FILE"
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
