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

echo "==> Instalando xfce4-panel-profiles y paquetes AUR..."
sudo -u "$REAL_USER" yay -S --needed --noconfirm \
  xfce4-panel-profiles-git \
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
# 7. APLICACIÓN DEL PERFIL REDMOND VIA D-BUS TEMPORAL
# ==========================================
echo "==> Cargando el perfil Redmond en el usuario $REAL_USER mediante D-Bus..."

if [ -f /usr/share/xfce4-panel-profiles/layouts/redmond.tar.bz2 ]; then
    sudo -u "$REAL_USER" dbus-run-session bash -c \
      "xfce4-panel-profiles load /usr/share/xfce4-panel-profiles/layouts/redmond.tar.bz2" || true
    
    # También se extrae directamente en /etc/skel para que futuros usuarios hereden la disposición Redmond
    sudo mkdir -p /etc/skel/.config/xfce4
    sudo tar -xjf /usr/share/xfce4-panel-profiles/layouts/redmond.tar.bz2 -C /etc/skel/.config/xfce4/ --strip-components=1 2>/dev/null || true
else
    echo "==> Advertencia: No se encontró el archivo de layout Redmond."
fi

# Ajustar permisos finales
sudo chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config"


# ==========================================
# 8. CONFIGURACIÓN DE SYSTEM SERVICES Y GRUB
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
# 9. LIMPIEZA Y REINICIO
# ==========================================
rm -rf ~/LinuxScripts

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Reiniciando el sistema en 5 segundos..."
echo "======================================================"
sleep 5
sudo reboot
