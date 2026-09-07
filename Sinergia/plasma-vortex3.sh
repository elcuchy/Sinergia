#!/bin/bash

# Exit on error, on unset variables, and propagate errors through pipes
set -euo pipefail

# Aviso de en qué línea falló el script, si falla
trap 'echo "==> ERROR: el script falló en la línea $LINENO (comando: $BASH_COMMAND)" >&2' ERR

# Identificar usuario real (en caso de ejecutar con sudo)
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")

# Función helper: descarga un archivo desde la KDE Store usando su API pública (OCS).
# Recibe el ID numérico de contenido (visible en la URL store.kde.org/p/<ID>) y la
# ruta de destino. El link real de descarga expira, así que se consulta en el momento.
fetch_kde_store_file() {
    local content_id="$1"
    local outfile="$2"
    local api_xml url

    api_xml=$(curl -s "https://api.kde-look.org/ocs/v1/content/data/$content_id")
    if [ -z "$api_xml" ]; then
        api_xml=$(curl -s "https://api.pling.com/ocs/v1/content/data/$content_id")
    fi

    url=$(echo "$api_xml" | grep -oP '(?<=<downloadlink1>)[^<]+' | head -n1)
    [ -n "$url" ] || url=$(echo "$api_xml" | grep -oP '(?<=<downloadlink>)[^<]+' | head -n1)
    url=$(echo "$url" | sed 's/&amp;/\&/g')

    if [ -z "$url" ]; then
        echo "==> Aviso: no se pudo obtener el link de descarga para el contenido $content_id de la KDE Store."
        return 1
    fi

    if curl -sL -o "$outfile" "$url"; then
        echo "==> Descargado desde la KDE Store (id $content_id): $outfile"
        return 0
    else
        echo "==> Aviso: falló la descarga desde $url"
        return 1
    fi
}

# Función helper: extrae un tar.gz o tar.xz detectando el formato automáticamente,
# ya que la KDE Store no siempre expone la extensión real en el nombre del link firmado.
extract_tar_auto() {
    local infile="$1" destdir="$2"
    if tar -tJf "$infile" &>/dev/null; then
        tar -xJf "$infile" -C "$destdir"
    elif tar -tzf "$infile" &>/dev/null; then
        tar -xzf "$infile" -C "$destdir"
    else
        tar -xf "$infile" -C "$destdir"
    fi
}

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
echo "==> Instalando Plasma, sddm, aplicaciones, dependencias y paquetes del sistema..."
sudo pacman -S --noconfirm --needed \
  plasma \
  sddm \
  sddm-kcm \
  amd-ucode \
  intel-ucode \
  okular \
  vlc \
  unrar \
  unarchiver \
  p7zip \
  firefox \
  firefox-i18n-es-ar \
  libreoffice-fresh-es \
  hunspell-es_uy \
  telegram-desktop \
  fastfetch \
  ntfs-3g \
  archlinux-tweak-tool-gtk4 \
  konsole \
  dolphin \
  kcalc \
  vlc-plugins-all \
  hardinfo2 \
  mpv \
  btop \
  gparted \
  nano \
  shelly \
  ark \
  powerdevil \
  plasma-systemmonitor \
  kwalletmanager \
  yakuake \
  kvantum \
  kvantum-qt5 \
  qbittorrent \
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
  os-prober


# ==========================================
# 4.1 DESINSTALACIÓN DE PAQUETES NO DESEADOS
# ==========================================
echo "==> Desinstalando discover..."
for pkg in discover; do
    if pacman -Qi "$pkg" &>/dev/null; then
        echo "==> Eliminando $pkg..."
        sudo pacman -Rns --noconfirm "$pkg"
    else
        echo "==> $pkg no está instalado, se omite."
    fi
done


# ==========================================
# 5. INSTALACIÓN DE YAY Y PAQUETES AUR
# ==========================================

echo "==> Asegurando base-devel e instalando YAY..."
sudo pacman -S --needed base-devel git --noconfirm

rm -rf yay
git clone https://aur.archlinux.org/yay.git
cd yay || exit
makepkg -si --noconfirm
cd ..
rm -rf yay

echo "==> Instalando paquetes adicionales..."
yay -S stacer-bin sinergia-dd-burner iptvnator-bin yamis-icon-theme-git fetch-git --noconfirm

# ==========================================
# 5.1 TEMA GLOBAL VORTEX-GLOBAL-6 (descargado en vivo desde la KDE Store)
# ==========================================
echo "==> Descargando e instalando el Tema Global Vortex-Global-6 desde la KDE Store..."
USER_UID=$(id -u "$REAL_USER")
RUNTIME_DIR="/run/user/$USER_UID"
if [ ! -d "$RUNTIME_DIR" ]; then
    RUNTIME_DIR=$(sudo -u "$REAL_USER" mktemp -d)
fi

GLOBALTHEME_ID="Vortex-Global-6"
VORTEX_TMP=$(sudo -u "$REAL_USER" mktemp -d)

if fetch_kde_store_file 2148697 "$VORTEX_TMP/Vortex-Global-6.pkg"; then
    LOOKANDFEEL_DIR="$USER_HOME/.local/share/plasma/look-and-feel"
    sudo -u "$REAL_USER" mkdir -p "$LOOKANDFEEL_DIR"
    sudo -u "$REAL_USER" rm -rf "$LOOKANDFEEL_DIR/Vortex-Global-6"
    if sudo -u "$REAL_USER" bash -c "$(declare -f extract_tar_auto); extract_tar_auto '$VORTEX_TMP/Vortex-Global-6.pkg' '$LOOKANDFEEL_DIR'"; then
        echo "==> Vortex-Global-6 extraído correctamente en $LOOKANDFEEL_DIR."
    else
        echo "==> Aviso: no se pudo extraer el paquete descargado de Vortex-Global-6."
    fi
else
    echo "==> Aviso: no se pudo descargar Vortex-Global-6 de la KDE Store, se mantiene el tema global anterior."
fi
rm -rf "$VORTEX_TMP"

LOOKANDFEEL_DIR="$USER_HOME/.local/share/plasma/look-and-feel"
if [ -d "$LOOKANDFEEL_DIR/Vortex-Global-6" ]; then
    if command -v plasma-apply-lookandfeel &>/dev/null; then
        echo "==> Ejecutando plasma-apply-lookandfeel -a $GLOBALTHEME_ID (modo offscreen)..."
        if sudo -u "$REAL_USER" env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$RUNTIME_DIR" \
            plasma-apply-lookandfeel -a "$GLOBALTHEME_ID"; then
            echo "==> plasma-apply-lookandfeel terminó sin errores."
        else
            echo "==> Aviso: plasma-apply-lookandfeel devolvió un error, se usará el respaldo directo sobre kdeglobals."
        fi
    fi

    KDEGLOBALS="$USER_HOME/.config/kdeglobals"
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
    if [ -f "$KDEGLOBALS" ] && grep -q "^\[KDE\]" "$KDEGLOBALS"; then
        if grep -q "^LookAndFeelPackage=" "$KDEGLOBALS"; then
            sudo -u "$REAL_USER" sed -i "s|^LookAndFeelPackage=.*|LookAndFeelPackage=$GLOBALTHEME_ID|" "$KDEGLOBALS"
        else
            sudo -u "$REAL_USER" sed -i "/^\[KDE\]/a LookAndFeelPackage=$GLOBALTHEME_ID" "$KDEGLOBALS"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '\n[KDE]\nLookAndFeelPackage=%s\n' '$GLOBALTHEME_ID' >> '$KDEGLOBALS'"
    fi
    echo "==> $GLOBALTHEME_ID fijado como Tema Global por defecto (incluye su propio splash screen embebido)."
fi

# ==========================================
# 5.2 ICONOS VORTEX-DARK-ICONS (descargado en vivo) + ÍCONO DE LANZADOR ARCH LINUX
# ==========================================
echo "==> Descargando e instalando el pack de iconos Vortex-Dark-Icons desde la KDE Store..."
ICONS_TMP=$(sudo -u "$REAL_USER" mktemp -d)
ICONS_DIR="$USER_HOME/.local/share/icons"
sudo -u "$REAL_USER" mkdir -p "$ICONS_DIR"

ICON_THEME_ID="Vortex-Dark-Icons"
if fetch_kde_store_file 1493433 "$ICONS_TMP/Vortex-Dark-Icons.pkg"; then
    sudo -u "$REAL_USER" rm -rf "$ICONS_DIR/Vortex-Dark-Icons"
    if sudo -u "$REAL_USER" bash -c "$(declare -f extract_tar_auto); extract_tar_auto '$ICONS_TMP/Vortex-Dark-Icons.pkg' '$ICONS_DIR'"; then
        echo "==> Vortex-Dark-Icons extraído correctamente en $ICONS_DIR."
    else
        echo "==> Aviso: no se pudo extraer el paquete descargado de Vortex-Dark-Icons."
    fi
else
    echo "==> Aviso: no se pudo descargar Vortex-Dark-Icons de la KDE Store."
fi
rm -rf "$ICONS_TMP"

# Buscar el archivo archlinux-logo que ya está presente en el sistema (viene con YAMIS)
echo "==> Buscando el archivo archlinux-logo ya presente en el sistema..."
ARCH_LOGO_FILE="/usr/share/icons/yet-another-monochrome-icon-set/apps/scalable/archlinux.svg"
if [ ! -f "$ARCH_LOGO_FILE" ]; then
    ARCH_LOGO_FILE=$(find /usr/share "$USER_HOME" -iname "archlinux-logo*" -type f \( -iname "*.svg" -o -iname "*.png" -o -iname "*.svgz" \) 2>/dev/null | head -n1 || true)
    if [ -z "$ARCH_LOGO_FILE" ]; then
        ARCH_LOGO_FILE=$(find /usr/share/icons "$USER_HOME/.local/share/icons" -iname "archlinux.svg" -type f 2>/dev/null | head -n1 || true)
    fi
fi
echo "==> Archivo archlinux-logo detectado: ${ARCH_LOGO_FILE:-(ninguno)}"

if [ -n "$ARCH_LOGO_FILE" ]; then
    ARCH_LOGO_EXT="${ARCH_LOGO_FILE##*.}"
    LAUNCHER_THEME_DIR="$USER_HOME/.local/share/icons/Vortex-ArchLauncher"
    sudo -u "$REAL_USER" mkdir -p "$LAUNCHER_THEME_DIR/scalable/apps" "$LAUNCHER_THEME_DIR/scalable/places"
    for name in start-here-kde-plasma start-here-kde start-here; do
        sudo -u "$REAL_USER" cp "$ARCH_LOGO_FILE" "$LAUNCHER_THEME_DIR/scalable/apps/$name.$ARCH_LOGO_EXT"
        sudo -u "$REAL_USER" cp "$ARCH_LOGO_FILE" "$LAUNCHER_THEME_DIR/scalable/places/$name.$ARCH_LOGO_EXT"
    done
    sudo -u "$REAL_USER" bash -c "cat > '$LAUNCHER_THEME_DIR/index.theme'" << EOF
[Icon Theme]
Name=Vortex-Dark-Icons with Arch Launcher
Comment=Vortex-Dark-Icons icon set with the Arch Linux launcher icon
Inherits=$ICON_THEME_ID,hicolor
Directories=scalable/apps,scalable/places

[scalable/apps]
Size=64
MinSize=8
MaxSize=512
Type=Scalable
Context=Applications

[scalable/places]
Size=64
MinSize=8
MaxSize=512
Type=Scalable
Context=Places
EOF
    echo "==> Tema de iconos compuesto Vortex-ArchLauncher creado (hereda de $ICON_THEME_ID)."
    ICON_THEME_ID="Vortex-ArchLauncher"

    LAYOUT_JS="/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js"
    if [ -f "$LAYOUT_JS" ]; then
        sudo cp "$LAYOUT_JS" "$LAYOUT_JS.bak_orig" 2>/dev/null || true
        sudo awk -v iconpath="$ARCH_LOGO_FILE" '
            {
                print
                if ($0 ~ /addWidget\("org\.kde\.plasma\.kickoff"\)/) {
                    varname = $0
                    sub(/^[ \t]*(var|let|const)[ \t]+/, "", varname)
                    sub(/[ \t]*=.*/, "", varname)
                    if (varname != "" && varname !~ / /) {
                        print varname ".currentConfigGroup = [\"General\"];"
                        print varname ".writeConfig(\"icon\", \"" iconpath "\");"
                    }
                }
            }
        ' "$LAYOUT_JS.bak_orig" | sudo tee "$LAYOUT_JS" > /dev/null
        echo "==> layout.js parcheado para usar $ARCH_LOGO_FILE como ícono del lanzador de aplicaciones."
    fi
else
    echo "==> Aviso: no se encontró ningún archivo archlinux-logo en el sistema, se usará Vortex-Dark-Icons sin ícono de lanzador personalizado."
fi

KDEGLOBALS="$USER_HOME/.config/kdeglobals"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if [ -f "$KDEGLOBALS" ] && grep -q "^\[Icons\]" "$KDEGLOBALS"; then
    if grep -q "^Theme=" "$KDEGLOBALS"; then
        sudo -u "$REAL_USER" sed -i "s|^Theme=.*|Theme=$ICON_THEME_ID|" "$KDEGLOBALS"
    else
        sudo -u "$REAL_USER" sed -i "/^\[Icons\]/a Theme=$ICON_THEME_ID" "$KDEGLOBALS"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[Icons]\nTheme=%s\n' '$ICON_THEME_ID' >> '$KDEGLOBALS'"
fi
echo "==> Icon theme $ICON_THEME_ID fijado por defecto."

# ==========================================
# 5.3 TRANSPARENCIA POR DEFECTO EN KONSOLE
# ==========================================
echo "==> Configurando transparencia por defecto en Konsole..."
KONSOLE_DATA_DIR="$USER_HOME/.local/share/konsole"
sudo -u "$REAL_USER" mkdir -p "$KONSOLE_DATA_DIR"

BASE_COLORSCHEME="/usr/share/konsole/Breeze.colorscheme"
TRANSPARENT_SCHEME="$KONSOLE_DATA_DIR/BreezeTransparent.colorscheme"
if [ -f "$BASE_COLORSCHEME" ]; then
    sudo -u "$REAL_USER" cp "$BASE_COLORSCHEME" "$TRANSPARENT_SCHEME"
else
    echo "==> Aviso: no se encontró el color scheme base de Breeze, se crea uno mínimo."
    sudo -u "$REAL_USER" bash -c "printf '[Background]\nColor=35,38,41\n[Foreground]\nColor=252,252,252\n[General]\nDescription=BreezeTransparent\n' > '$TRANSPARENT_SCHEME'"
fi
if grep -q "^\[General\]" "$TRANSPARENT_SCHEME" && grep -q "^Opacity=" "$TRANSPARENT_SCHEME"; then
    sudo -u "$REAL_USER" sed -i "s|^Opacity=.*|Opacity=0.85|" "$TRANSPARENT_SCHEME"
elif grep -q "^\[General\]" "$TRANSPARENT_SCHEME"; then
    sudo -u "$REAL_USER" sed -i "/^\[General\]/a Opacity=0.85" "$TRANSPARENT_SCHEME"
else
    sudo -u "$REAL_USER" bash -c "printf '\n[General]\nOpacity=0.85\n' >> '$TRANSPARENT_SCHEME'"
fi

TRANSPARENT_PROFILE="$KONSOLE_DATA_DIR/Transparent.profile"
sudo -u "$REAL_USER" bash -c "printf '[Appearance]\nColorScheme=BreezeTransparent\n\n[General]\nName=Transparent\nParent=FALLBACK/\n' > '$TRANSPARENT_PROFILE'"

KONSOLERC="$USER_HOME/.config/konsolerc"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if [ -f "$KONSOLERC" ] && grep -q "^\[Desktop Entry\]" "$KONSOLERC"; then
    if grep -q "^DefaultProfile=" "$KONSOLERC"; then
        sudo -u "$REAL_USER" sed -i "s|^DefaultProfile=.*|DefaultProfile=Transparent.profile|" "$KONSOLERC"
    else
        sudo -u "$REAL_USER" sed -i "/^\[Desktop Entry\]/a DefaultProfile=Transparent.profile" "$KONSOLERC"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '[Desktop Entry]\nDefaultProfile=Transparent.profile\n' >> '$KONSOLERC'"
fi
echo "==> Konsole configurado con transparencia (Opacity=0.85) como perfil por defecto."

# Habilitar el efecto de escritorio Blur, para que la transparencia se vea bien
KWINRC="$USER_HOME/.config/kwinrc"
sudo -u "$REAL_USER" touch "$KWINRC"
if grep -q "^\[Plugins\]" "$KWINRC" 2>/dev/null; then
    if grep -q "^blurEnabled=" "$KWINRC"; then
        sudo -u "$REAL_USER" sed -i "s|^blurEnabled=.*|blurEnabled=true|" "$KWINRC"
    else
        sudo -u "$REAL_USER" sed -i "/^\[Plugins\]/a blurEnabled=true" "$KWINRC"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[Plugins]\nblurEnabled=true\n' >> '$KWINRC'"
fi

# ==========================================
# 5.4 FONDO DE PANTALLA VORTEX-WALLPAPER (descargado en vivo desde la KDE Store)
# ==========================================
echo "==> Descargando el fondo de pantalla Vortex-Wallpaper desde la KDE Store..."
WALLPAPER_TMP=$(mktemp -d)
WALLPAPER_OK=0

if fetch_kde_store_file 1493412 "$WALLPAPER_TMP/vortex-wallpaper.pkg"; then
    WALLPAPER_OK=1
elif fetch_kde_store_file 1493413 "$WALLPAPER_TMP/vortex-wallpaper.pkg"; then
    WALLPAPER_OK=1
fi

sudo mkdir -p /usr/share/wallpapers

if [ "$WALLPAPER_OK" = "1" ]; then
    # El archivo descargado puede ser directamente la imagen, o un paquete
    # comprimido que contiene "Vortex-Wallpaper.png" adentro. Se detectan ambos casos.
    if file "$WALLPAPER_TMP/vortex-wallpaper.pkg" | grep -qi "PNG image"; then
        sudo cp "$WALLPAPER_TMP/vortex-wallpaper.pkg" /usr/share/wallpapers/Vortex-Wallpaper.png
    else
        extract_tar_auto "$WALLPAPER_TMP/vortex-wallpaper.pkg" "$WALLPAPER_TMP/extracted" 2>/dev/null
        FOUND_PNG=$(find "$WALLPAPER_TMP/extracted" -iname "Vortex-Wallpaper*.png" 2>/dev/null | head -n1 || true)
        [ -n "$FOUND_PNG" ] || FOUND_PNG=$(find "$WALLPAPER_TMP/extracted" -iname "*.png" -o -iname "*.jpg" 2>/dev/null | head -n1 || true)
        if [ -n "$FOUND_PNG" ]; then
            sudo cp "$FOUND_PNG" /usr/share/wallpapers/Vortex-Wallpaper.png
        else
            WALLPAPER_OK=0
        fi
    fi
fi

if [ "$WALLPAPER_OK" = "1" ] && [ -f /usr/share/wallpapers/Vortex-Wallpaper.png ]; then
    echo "==> Vortex-Wallpaper.png instalado en /usr/share/wallpapers/"

    if command -v plasma-apply-wallpaperimage &>/dev/null; then
        sudo -u "$REAL_USER" env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$RUNTIME_DIR" \
            plasma-apply-wallpaperimage "/usr/share/wallpapers/Vortex-Wallpaper.png" || \
            echo "==> Aviso: no se pudo aplicar el fondo de pantalla en vivo (normal si no hay sesión gráfica activa); quedará aplicado en el próximo inicio de sesión vía Vortex-Global-6."
    fi
else
    echo "==> Aviso: no se pudo obtener Vortex-Wallpaper.png de la KDE Store."
fi
rm -rf "$WALLPAPER_TMP"

# ==========================================
# 6. CONFIGURACIÓN DE SYSTEM SERVICES, SDDM Y GRUB
# ==========================================
echo "==> Descargando e instalando el tema Vortex-SDDM-6 desde la KDE Store..."

SDDM_TMP=$(mktemp -d)
if fetch_kde_store_file 2148693 "$SDDM_TMP/Vortex-SDDM-6.pkg"; then
    sudo mkdir -p /usr/share/sddm/themes
    sudo rm -rf /usr/share/sddm/themes/Vortex-SDDM-6
    if extract_tar_auto "$SDDM_TMP/Vortex-SDDM-6.pkg" /usr/share/sddm/themes; then
        echo "==> Vortex-SDDM-6 instalado en /usr/share/sddm/themes/Vortex-SDDM-6."
    else
        echo "==> Aviso: no se pudo extraer el paquete descargado de Vortex-SDDM-6."
    fi
else
    echo "==> Aviso: no se pudo descargar Vortex-SDDM-6 de la KDE Store."
fi
rm -rf "$SDDM_TMP"

if [ -d /usr/share/sddm/themes/Vortex-SDDM-6 ]; then
    echo "==> Configurando /etc/sddm.conf.d/theme.conf.user..."
    sudo mkdir -p /etc/sddm.conf.d
    sudo bash -c 'cat > /etc/sddm.conf.d/theme.conf.user' << EOF
[Theme]
Current=Vortex-SDDM-6
EOF
fi

echo "==> Habilitando SDDM como Display Manager..."
# Deshabilitar otros DMs si están activos para evitar conflictos
for dm in entrance gdm lightdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        echo "==> Deshabilitando $dm..."
        sudo systemctl disable "$dm"
    fi
done

sudo systemctl enable sddm

# ==========================================
# 6.1 DESACTIVAR KDE WALLET POR DEFECTO
# ==========================================
echo "==> Desactivando KDE Wallet por defecto para $REAL_USER..."
KWALLET_CONFIG="$USER_HOME/.config/kwalletrc"

sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"

if [ -f "$KWALLET_CONFIG" ]; then
    if grep -q "^\[Wallet\]" "$KWALLET_CONFIG"; then
        sudo -u "$REAL_USER" sed -i '/^\[Wallet\]/,/^\[/{s/^Enabled=.*/Enabled=false/}' "$KWALLET_CONFIG"
        if ! grep -A5 "^\[Wallet\]" "$KWALLET_CONFIG" | grep -q "^Enabled="; then
            sudo -u "$REAL_USER" sed -i '/^\[Wallet\]/a Enabled=false' "$KWALLET_CONFIG"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '\n[Wallet]\nEnabled=false\n' >> '$KWALLET_CONFIG'"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '[Wallet]\nEnabled=false\n' > '$KWALLET_CONFIG'"
fi


# ==========================================
# 7. LIMPIEZA Y REINICIO
# ==========================================
rm -rf "$USER_HOME/LinuxScripts"

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Display manager configurado: SDDM"
echo " KDE Wallet: desactivado por defecto"
echo " Tema Global: Vortex-Global-6 (con splash embebido)
 Pantalla de inicio de sesión (SDDM): Vortex-SDDM-6
 Icon theme: Vortex-Dark-Icons con ícono de lanzador Arch Linux
 Konsole: transparencia por defecto (Opacity=0.85)
 Fondo de pantalla: Vortex-Wallpaper.png"
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
