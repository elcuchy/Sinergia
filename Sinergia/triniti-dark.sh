#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO Y PACMAN
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
fi

# Agregar ILoveCandy y habilitar ParallelDownloads si no existen
echo "==> Activando ILoveCandy y descargas paralelas en pacman.conf..."
if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    # Inserta ILoveCandy justo debajo de la cabecera [options]
    sudo sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi

if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf
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


# Exit on error (si un comando falla, el script se detiene por seguridad)
set -e

# ==========================================
# 4. REPOSITORIO E INSTALACIÓN DE TRINITY DESKTOP (TDE)
# ==========================================

# 4.1 Agregar el repositorio de Trinity Desktop (si no existe ya en pacman.conf)
if ! grep -q "\[trinity\]" /etc/pacman.conf; then
  echo "Añadiendo el repositorio [trinity] a /etc/pacman.conf..."
  sudo bash -c 'cat <<EOF >> /etc/pacman.conf

[trinity]
Server = https://mirror.ppa.trinitydesktop.org/trinity/archlinux/\$arch
EOF'
fi

# 4.2 Recibir y firmar la llave GPG
sudo pacman-key --recv-key D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B
sudo pacman-key --lsign-key D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B

# 4.3 Actualizar las bases de datos de repositorios
sudo pacman -Sy --noconfirm

# 4.4 Instalar TDE y el resto de los paquetes
#     (librsvg se usa más abajo para convertir el logo de Arch a PNG)
sudo pacman -S --noconfirm \
  tde-tdebase \
  tde-tdeartwork \
  tde-i18n-es \
  amd-ucode \
  intel-ucode \
  okular \
  vlc \
  ark \
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
  vlc-plugins-all \
  hardinfo2 \
  mpv \
  btop \
  gparted \
  nano \
  ulauncher \
  audacious \
  octopi \
  kget \
  librsvg \
  papirus-icon-theme \
  tde-dolphin \
  tde-kmplayer \
  tde-ksquirrel \
  tde-ktorrent \
  tde-style-baghira \
  tde-style-domino \
  tde-style-ia-ora \
  tde-style-lipstik \
  tde-style-polyester \
  tde-style-qtcurve \
  tde-tdebluez \
  tde-tdemultimedia \
  tde-tdenetwork \
  tde-tdenetworkmanager \
  tde-tdmtheme \
  tde-twin-style-crystal \
  tde-twin-style-dekorator \
  tde-twin-style-fahrenheit \
  tde-twin-style-machbunt \
  tde-twin-style-mallory \
  tde-twin-style-suse2 \
  tde-yakuake \
  os-prober

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
yay -S stacer-bin sinergia-dd-burner iptvnator-bin --noconfirm

# ==========================================
# 6. CONFIGURACIONES DE TRINITY DESKTOP (TDE)
# ==========================================
echo "==> Aplicando personalizaciones de Trinity Desktop..."

# Determinar el usuario real si el script se ejecuta con sudo
TARGET_USER=${SUDO_USER:-$USER}
TARGET_HOME=$(eval echo "~$TARGET_USER")
TDE_CONFIG="$TARGET_HOME/.trinity/share/config"

# Crear estructura de carpetas de configuración del usuario
mkdir -p "$TDE_CONFIG"

# ------------------------------------------
# 6.1 ESQUEMA DE COLORES: MALLORY NIGHTSHIFT
# ------------------------------------------
echo "==> Configurando esquema de colores Mallory Nightshift..."

COLOR_DIR="$TARGET_HOME/.trinity/share/apps/tdedisplay/color-schemes"
mkdir -p "$COLOR_DIR"

# Paleta (un solo lugar para cambiar los colores)
C_BG="40,44,52"            # fondo general de ventanas y diálogos
C_FG="220,224,230"         # texto general
C_ALT="45,49,58"           # filas alternas en listas
C_BTN="50,54,66"           # botones
C_SEL="82,108,145"         # selección
C_SEL_FG="255,255,255"
C_LINK="136,192,208"
C_VISITED="180,142,173"
C_ACT="48,52,65"           # barra de título activa
C_ACT_FG="229,233,240"
C_INACT="35,38,48"         # barra de título inactiva
C_INACT_FG="160,165,180"

# Esquema guardado, para que aparezca en Centro de Control > Colores
cat << EOF > "$COLOR_DIR/MalloryNightshift.kcsrc"
[Color Scheme]
Name=Mallory Nightshift
background=$C_BG
foreground=$C_FG
windowBackground=$C_BG
windowForeground=$C_FG
alternateBackground=$C_ALT
buttonBackground=$C_BTN
buttonForeground=$C_FG
selectBackground=$C_SEL
selectForeground=$C_SEL_FG
linkColor=$C_LINK
visitedLinkColor=$C_VISITED
activeBackground=$C_ACT
activeBlend=$C_ACT
activeForeground=$C_ACT_FG
activeTitleBtnBg=$C_ACT
inactiveBackground=$C_INACT
inactiveBlend=$C_INACT
inactiveForeground=$C_INACT_FG
inactiveTitleBtnBg=$C_INACT
frame=$C_BG
handle=$C_BG
inactiveFrame=$C_BG
inactiveHandle=$C_BG
contrast=4
EOF

# Colores activos, idioma y tema de iconos: TDE los lee de kdeglobals en
# formato KDE3 ([General], [WM], [KDE], [Locale] e [Icons]); los grupos
# [Colors:*] se ignoran.
[ -f "$TDE_CONFIG/kdeglobals" ] && cp "$TDE_CONFIG/kdeglobals" "$TDE_CONFIG/kdeglobals.bak"

cat << EOF > "$TDE_CONFIG/kdeglobals"
[General]
background=$C_BG
foreground=$C_FG
windowBackground=$C_BG
windowForeground=$C_FG
alternateBackground=$C_ALT
buttonBackground=$C_BTN
buttonForeground=$C_FG
selectBackground=$C_SEL
selectForeground=$C_SEL_FG
linkColor=$C_LINK
visitedLinkColor=$C_VISITED

[WM]
activeBackground=$C_ACT
activeBlend=$C_ACT
activeForeground=$C_ACT_FG
activeTitleBtnBg=$C_ACT
inactiveBackground=$C_INACT
inactiveBlend=$C_INACT
inactiveForeground=$C_INACT_FG
inactiveTitleBtnBg=$C_INACT
frame=$C_BG
handle=$C_BG
inactiveFrame=$C_BG
inactiveHandle=$C_BG

[KDE]
colorScheme=MalloryNightshift.kcsrc
contrast=4

[Locale]
Country=uy
Language=es

[Icons]
Theme=Papirus-Dark
EOF

# ------------------------------------------
# 6.2 SALTAR EL ASISTENTE DE PRIMER INICIO (KPERSONALIZER)
# ------------------------------------------
# Si aparece, vuelve a escribir estilo y colores por defecto encima de los nuestros.
cat << 'EOF' > "$TDE_CONFIG/kpersonalizerrc"
[General]
FirstLogin=false
EOF

# ------------------------------------------
# 6.3 PANEL (KICKER): TRANSPARENCIA Y LOGO DE ARCH EN EL MENÚ
# ------------------------------------------
echo "==> Configurando el panel..."

# Convertir el logo de Arch a PNG para el botón del menú
MENU_ICON="$TARGET_HOME/.trinity/share/icons/arch-menu.png"
mkdir -p "$(dirname "$MENU_ICON")"
rsvg-convert -w 64 -h 64 /usr/share/pixmaps/archlinux-logo.svg -o "$MENU_ICON"

cat << EOF >> "$TDE_CONFIG/kickerrc"

[General]
Transparent=true
Tint=false
TintColor=0,0,0
TransparentAmount=30

[KMenu]
CustomIcon=$MENU_ICON
EOF

# ------------------------------------------
# 6.4 KONSOLE Y YAKUAKE: FONDO NEGRO TRANSPARENTE
# ------------------------------------------
echo "==> Configurando Konsole y Yakuake..."

# Konsole
cat << 'EOF' >> "$TDE_CONFIG/konsolerc"

[Desktop Entry]
schema=Transparent_darkbg.schema
EOF

# Yakuake (usa el componente de terminal incrustado de Konsole)
cat << 'EOF' >> "$TDE_CONFIG/konsolepartrc"

[Desktop Entry]
schema=Transparent_darkbg.schema
EOF

# Iniciar Yakuake con la sesión, para que F12 lo despliegue
mkdir -p "$TARGET_HOME/.trinity/Autostart"
cat << 'EOF' > "$TARGET_HOME/.trinity/Autostart/yakuake.desktop"
[Desktop Entry]
Type=Application
Name=Yakuake
Exec=yakuake
Icon=yakuake
EOF

# ------------------------------------------
# 6.5 FONDO DE PANTALLA POR DEFECTO
# ------------------------------------------
echo "==> Descargando y configurando el fondo de pantalla..."

WALLPAPER="$TARGET_HOME/.trinity/share/wallpapers/arch-10.png"
WALLPAPER_URL="https://raw.githubusercontent.com/f4dzN/archlinux-wallpapers/refs/heads/main/wallpapers/10.png"
mkdir -p "$(dirname "$WALLPAPER")"

if curl -fL -o "$WALLPAPER" "$WALLPAPER_URL"; then
    cat << EOF >> "$TDE_CONFIG/kdesktoprc"

[Background Common]
CommonDesktop=true

[Desktop0]
Wallpaper=$WALLPAPER
WallpaperMode=ScaleAndCrop
MultiWallpaperMode=NoMulti
EOF
else
    echo "==> No se pudo descargar el fondo; se deja el de Trinity por defecto."
fi

# ------------------------------------------
# 6.6 ULAUNCHER: INICIO AUTOMÁTICO Y TEMA OSCURO
# ------------------------------------------
echo "==> Configurando Ulauncher..."

# Iniciar Ulauncher con la sesión (oculto, se abre con Ctrl+Espacio)
mkdir -p "$TARGET_HOME/.trinity/Autostart"
cat << 'EOF' > "$TARGET_HOME/.trinity/Autostart/ulauncher.desktop"
[Desktop Entry]
Type=Application
Name=Ulauncher
Exec=ulauncher --hide-window
Icon=ulauncher
EOF

# Tema oscuro (solo si el usuario todavía no tiene configuración propia)
ULAUNCHER_DIR="$TARGET_HOME/.config/ulauncher"
mkdir -p "$ULAUNCHER_DIR"
if [ ! -f "$ULAUNCHER_DIR/settings.json" ]; then
    cat << 'EOF' > "$ULAUNCHER_DIR/settings.json"
{
    "hotkey-show-app": "<Primary>space",
    "theme-name": "dark"
}
EOF
fi

# ------------------------------------------
# 6.7 PERMISOS DE LA CONFIGURACIÓN DEL USUARIO
# ------------------------------------------
# Si el script se corrió con sudo, devolver los archivos al usuario
if [ "$(id -u)" -eq 0 ]; then
    chown -R "$TARGET_USER": "$TARGET_HOME/.trinity" "$ULAUNCHER_DIR"
    chown "$TARGET_USER": "$TARGET_HOME/.config"
fi

# ------------------------------------------
# 6.8 CAMBIAR TEMA DE TDM A MINIMALISTA (GLOBAL)
# ------------------------------------------
echo "==> Configurando el tema Minimalista en el gestor de inicio TDM..."

TDM_CONFIG_FILE="/opt/trinity/share/config/tdm/tdmrc"
[ ! -f "$TDM_CONFIG_FILE" ] && TDM_CONFIG_FILE="/etc/trinity/tdm/tdmrc"

# Ruta del tema Minimalista (busca en la ruta predeterminada de Trinity)
THEME_PATH="/opt/trinity/share/apps/tdm/themes/minimalist"
[ ! -d "$THEME_PATH" ] && THEME_PATH="/usr/share/apps/tdm/themes/minimalist"

if [ -f "$TDM_CONFIG_FILE" ]; then
    # Habilitar el uso de temas si no está habilitado
    sudo sed -i 's/^#\?UseTheme=.*/UseTheme=true/' "$TDM_CONFIG_FILE"

    # Asignar la ruta del tema Minimalista
    sudo sed -i "s|^#\?Theme=.*|Theme=$THEME_PATH|" "$TDM_CONFIG_FILE"
else
    # Crear estructura e insertar la configuración por defecto
    sudo mkdir -p /etc/trinity/tdm/
    sudo bash -c "cat << EOF > /etc/trinity/tdm/tdmrc
[X-*-Greeter]
UseTheme=true
Theme=$THEME_PATH
EOF"
fi

# ==========================================
# 7. GRUB, GESTOR DE INICIO Y REINICIO
# ==========================================

# Configurar GRUB para detectar otros sistemas operativos
sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Habilitar el gestor de inicio de TDE
sudo systemctl enable tdm.service

# Limpieza opcional
rm -rf ~/LinuxScripts

# Reiniciar
echo "Instalación completada. Reiniciando el sistema..."
sudo reboot
