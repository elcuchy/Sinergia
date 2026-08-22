#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO Y PACMAN
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
fi

# Agregar ILoveCandy y habilitar ParallelDownloads si no existen (CORREGIDO)
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

# 1. Agregar el repositorio de Trinity Desktop (si no existe ya en pacman.conf)
if ! grep -q "\[trinity\]" /etc/pacman.conf; then
  echo "Añadiendo el repositorio [trinity] a /etc/pacman.conf..."
  sudo bash -c 'cat <<EOF >> /etc/pacman.conf

[trinity]
Server = https://mirror.ppa.trinitydesktop.org/trinity/archlinux/\$arch
EOF'
fi

# 2. Recibir y firmar la llave GPG
sudo pacman-key --recv-key D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B
sudo pacman-key --lsign-key D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B

# 3. Actualizar las bases de datos de repositorios
sudo pacman -Sy --noconfirm

# 4. Instalar TDE y el resto de los paquetes
sudo pacman -S --noconfirm \
  tde-tdebase \
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
  terminology \
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
# . INSTALACIÓN DE YAY Y PAQUETES AUR
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
yay -S stacer-bin --noconfirm

# ==========================================
# CONFIGURACIONES DE TRINITY DESKTOP (TDE)
# ==========================================
echo "==> Aplicando personalizaciones de Trinity Desktop..."

# Determinar el usuario real si el script se ejecuta con sudo
TARGET_USER=${SUDO_USER:-$USER}
TARGET_HOME=$(eval echo "~$TARGET_USER")
TDE_CONFIG="$TARGET_HOME/.trinity/share/config"

# Crear estructura de carpetas de configuración del usuario
mkdir -p "$TDE_CONFIG"
mkdir -p "$TARGET_HOME/.trinity/share/apps/color-schemes"

# ------------------------------------------
# 1. ESQUEMA DE COLORES: MALLORY NIGHTSHIFT
# ------------------------------------------
echo "==> Configurando esquema de colores Mallory Nightshift..."

# Descargar o escribir el esquema de colores Mallory Nightshift
cat << 'EOF' > "$TARGET_HOME/.trinity/share/apps/color-schemes/MalloryNightshift.kcsrc"
[Color Scheme]
Name=Mallory Nightshift
activeBackground=48,52,65
activeForeground=229,233,240
inactiveBackground=35,38,48
inactiveForeground=160,165,180
windowBackground=40,44,52
windowForeground=220,224,230
selectBackground=82,108,145
selectForeground=255,255,255
buttonBackground=50,54,66
buttonForeground=220,224,230
link=136,192,208
visitedLink=180,142,173
EOF

# Aplicar el esquema en kdeglobals
cat << 'EOF' >> "$TDE_CONFIG/kdeglobals"

[General]
colorScheme=MalloryNightshift.kcsrc

[WM]
activeBackground=48,52,65
activeForeground=229,233,240
inactiveBackground=35,38,48
inactiveForeground=160,165,180
EOF

# ------------------------------------------
# 2. TRANSPARENCIA EN EL PANEL INFERIOR (KICKER)
# ------------------------------------------
echo "==> Activando transparencia en el panel..."

cat << 'EOF' >> "$TDE_CONFIG/kickerrc"

[General]
Transparent=true
Tint=false
TintColor=0,0,0
TransparentAmount=30
EOF

# ------------------------------------------
# 3. CAMBIAR ÍCONO DEL MENÚ TDE A ARCHLINUX
# ------------------------------------------
echo "==> Cambiando el ícono del menú de inicio por Arch Linux..."

KICKER_CONF="$TDE_CONFIG/kickerrc"

# Asegurar que el directorio contenedor exista
mkdir -p "$(dirname "$KICKER_CONF")"

if [ -f "$KICKER_CONF" ] && grep -q "\[KMenu\]" "$KICKER_CONF"; then
    # Si la sección [KMenu] existe, actualizamos o insertamos las claves
    grep -q "^UseCustomButtonIcon=" "$KICKER_CONF" \
        && sed -i 's/^UseCustomButtonIcon=.*/UseCustomButtonIcon=true/' "$KICKER_CONF" \
        || sed -i '/\[KMenu\]/a UseCustomButtonIcon=true' "$KICKER_CONF"

    grep -q "^CustomButtonIcon=" "$KICKER_CONF" \
        && sed -i 's/^CustomButtonIcon=.*/CustomButtonIcon=archlinux/' "$KICKER_CONF" \
        || sed -i '/\[KMenu\]/a CustomButtonIcon=archlinux' "$KICKER_CONF"
else
    # Si el archivo o la sección no existen, los añadimos al final
    cat << 'EOF' >> "$KICKER_CONF"

[KMenu]
CustomButtonIcon=archlinux
UseCustomButtonIcon=true
EOF
fi

# ------------------------------------------
# 4. CONFIGURAR FONDO DE KONQUEROR AL COLOR DEL ESQUEMA
# ------------------------------------------
echo "==> Ajustando color de fondo de Konqueror..."

cat << 'EOF' >> "$TDE_CONFIG/konquerorrc"

[FmView Properties]
BackgroundMode=1
BackgroundColor=40,44,52
EOF

# Ajustar permisos de los archivos creados en el HOME del usuario
chown -R "$TARGET_USER:" "$TARGET_HOME/.trinity"

# ------------------------------------------
# 5. CAMBIAR TEMA DE TDM A MINIMALISTA (GLOBAL)
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

# 5. Configurar GRUB para detectar otros sistemas operativos
sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 6. Habilitar el gestor de inicio de TDE
sudo systemctl enable tdm.service

# 7. Limpieza opcional
rm -rf ~/LinuxScripts

# 8. Reiniciar
echo "Instalación completada. Reiniciando el sistema..."
sudo reboot




