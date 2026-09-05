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
# 5.1 TEMA GLOBAL BREEZE DARK POR DEFECTO
# ==========================================
echo "==> Fijando Breeze Dark como Tema Global por defecto..."
BREEZEDARK_ID="org.kde.breezedark.desktop"
USER_UID=$(id -u "$REAL_USER")
RUNTIME_DIR="/run/user/$USER_UID"
if [ ! -d "$RUNTIME_DIR" ]; then
    RUNTIME_DIR=$(sudo -u "$REAL_USER" mktemp -d)
fi

sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if command -v plasma-apply-lookandfeel &>/dev/null; then
    sudo -u "$REAL_USER" env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$RUNTIME_DIR" \
        plasma-apply-lookandfeel -a "$BREEZEDARK_ID" || \
        echo "==> Aviso: plasma-apply-lookandfeel devolvió un error, se usará el respaldo directo sobre kdeglobals."
else
    echo "==> Aviso: plasma-apply-lookandfeel no está disponible, se usará el respaldo directo sobre kdeglobals."
fi

KDEGLOBALS="$USER_HOME/.config/kdeglobals"
if [ -f "$KDEGLOBALS" ] && grep -q "^\[KDE\]" "$KDEGLOBALS"; then
    if grep -q "^LookAndFeelPackage=" "$KDEGLOBALS"; then
        sudo -u "$REAL_USER" sed -i "s|^LookAndFeelPackage=.*|LookAndFeelPackage=$BREEZEDARK_ID|" "$KDEGLOBALS"
    else
        sudo -u "$REAL_USER" sed -i "/^\[KDE\]/a LookAndFeelPackage=$BREEZEDARK_ID" "$KDEGLOBALS"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[KDE]\nLookAndFeelPackage=%s\n' '$BREEZEDARK_ID' >> '$KDEGLOBALS'"
fi
echo "==> Breeze Dark fijado como Tema Global por defecto."

# ==========================================
# 5.2 ICONOS YAMIS POR DEFECTO + ÍCONO DE LANZADOR ARCH LINUX EN BLANCO
# ==========================================
echo "==> Configurando iconos YAMIS por defecto..."
YAMIS_DIR=$(find /usr/share/icons "$USER_HOME/.local/share/icons" -maxdepth 1 -type d \( -iname "*yamis*" -o -iname "*yet*monochrome*" -o -iname "*another-monochrome*" \) 2>/dev/null | head -n1 || true)
echo "==> Carpeta de iconos YAMIS detectada: ${YAMIS_DIR:-(ninguna)}"

ICON_THEME_ID="YAMIS"
if [ -n "$YAMIS_DIR" ]; then
    ICON_THEME_ID=$(basename "$YAMIS_DIR")
else
    echo "==> Aviso: no se encontró la carpeta de YAMIS instalada, se usará el nombre 'YAMIS' de todos modos por si el paquete la crea más tarde."
fi

# Armar un pequeño tema de iconos propio que hereda de YAMIS y solo reemplaza
# el ícono del lanzador de aplicaciones (Kickoff) por el logo de Arch Linux en blanco
echo "==> Descargando y recoloreando el logo de Arch Linux en blanco..."
ARCH_ICON_TMP=$(sudo -u "$REAL_USER" mktemp -d)
if sudo -u "$REAL_USER" wget -q -O "$ARCH_ICON_TMP/archlinux-icon.svg" "https://www.vectorlogo.zone/logos/archlinux/archlinux-icon.svg"; then
    sudo -u "$REAL_USER" sed -i 's|<svg\([^>]*\)>|<svg\1><style>*{fill:#ffffff !important;stroke:none !important;}</style>|' "$ARCH_ICON_TMP/archlinux-icon.svg"

    LAUNCHER_THEME_DIR="$USER_HOME/.local/share/icons/YAMIS-ArchLauncher"
    sudo -u "$REAL_USER" mkdir -p "$LAUNCHER_THEME_DIR/scalable/apps" "$LAUNCHER_THEME_DIR/scalable/places"
    for name in start-here-kde-plasma start-here-kde start-here; do
        sudo -u "$REAL_USER" cp "$ARCH_ICON_TMP/archlinux-icon.svg" "$LAUNCHER_THEME_DIR/scalable/apps/$name.svg"
        sudo -u "$REAL_USER" cp "$ARCH_ICON_TMP/archlinux-icon.svg" "$LAUNCHER_THEME_DIR/scalable/places/$name.svg"
    done

    sudo -u "$REAL_USER" bash -c "cat > '$LAUNCHER_THEME_DIR/index.theme'" << EOF
[Icon Theme]
Name=YAMIS with Arch Launcher
Comment=YAMIS icon set with a white Arch Linux launcher icon
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
    echo "==> Tema de iconos compuesto YAMIS-ArchLauncher creado (hereda de $ICON_THEME_ID)."
    ICON_THEME_ID="YAMIS-ArchLauncher"
else
    echo "==> Aviso: no se pudo descargar el logo de Arch Linux, se usará YAMIS sin el ícono de lanzador personalizado."
fi
rm -rf "$ARCH_ICON_TMP"

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
# 5.4 FONDO DE PANTALLA POR DEFECTO
# ==========================================
echo "==> Configurando el fondo de pantalla por defecto..."
WALLPAPER_PKG_DIR="/usr/share/wallpapers/CustomArchWallpaper"
sudo mkdir -p "$WALLPAPER_PKG_DIR/contents/images"

if sudo wget -q -O "$WALLPAPER_PKG_DIR/contents/images/1920x1080.jpg" \
    "https://raw.githubusercontent.com/UncleSpellbinder/Arch-Linux-HD-Wallpaper/main/ARCH_2__1920x1080.jpg"; then

    sudo bash -c "cat > '$WALLPAPER_PKG_DIR/metadata.desktop'" << 'EOF'
[Desktop Entry]
Name=Custom Arch Wallpaper
Type=Service
X-KDE-ServiceTypes=Plasma/Wallpaper
X-KDE-PluginInfo-Name=customarchwallpaper
EOF

    LNF_DEFAULTS="/usr/share/plasma/look-and-feel/org.kde.breezedark.desktop/contents/defaults"
    if [ -f "$LNF_DEFAULTS" ]; then
        if grep -q "^\[Wallpaper\]" "$LNF_DEFAULTS"; then
            if grep -q "^Image=" "$LNF_DEFAULTS"; then
                sudo sed -i "s|^Image=.*|Image=CustomArchWallpaper|" "$LNF_DEFAULTS"
            else
                sudo sed -i "/^\[Wallpaper\]/a Image=CustomArchWallpaper" "$LNF_DEFAULTS"
            fi
        else
            sudo bash -c "printf '\n[Wallpaper]\nImage=CustomArchWallpaper\n' >> '$LNF_DEFAULTS'"
        fi
        echo "==> Fondo de pantalla por defecto de Breeze Dark cambiado a CustomArchWallpaper."
    else
        echo "==> Aviso: no se encontró el archivo defaults de Breeze Dark, no se pudo fijar el wallpaper por defecto del tema."
    fi

    # Intento de aplicación en vivo (solo tiene efecto si hay una sesión de Plasma activa)
    if command -v plasma-apply-wallpaperimage &>/dev/null; then
        sudo -u "$REAL_USER" plasma-apply-wallpaperimage "$WALLPAPER_PKG_DIR/contents/images/1920x1080.jpg" || \
            echo "==> Aviso: no se pudo aplicar el fondo de pantalla en vivo (normal si no hay sesión gráfica activa); quedará aplicado en el próximo inicio de sesión."
    fi
else
    echo "==> Aviso: no se pudo descargar el fondo de pantalla desde GitHub, se omite este paso."
fi


# ==========================================
echo "==> Configurando sddm como display manager por defecto..."

# Si hay otro DM habilitado, lo deshabilitamos para evitar conflictos
for dm in entrance gdm lightdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        echo "==> Deshabilitando $dm..."
        sudo systemctl disable "$dm"
    fi
done

sudo systemctl enable sddm

echo "==> Configurando GRUB para detectar otros SO..."
if [ -f /etc/default/grub ]; then
    sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi


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
echo " Tema Global: Breeze Dark
 Icon theme: YAMIS con ícono de lanzador Arch Linux en blanco
 Konsole: transparencia por defecto (Opacity=0.85)
 Fondo de pantalla: Arch HD Wallpaper (GitHub)"
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
