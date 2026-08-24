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


# ==========================================
# 4. INSTALACIÓN DE PAQUETES OFICIALES Y CHAOTIC-AUR
# ==========================================
echo "==> Instalando XFCE, aplicaciones y paquetes del sistema..."
sudo pacman -S --noconfirm --needed \
  xorg-server \
  xorg-apps \
  xfce4 \
  xfce4-goodies \
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

rm -rf yay
git clone https://aur.archlinux.org/yay.git
cd yay || exit
makepkg -si --noconfirm
cd ..
rm -rf yay

echo "==> Instalando paquetes adicionales desde AUR..."
yay -S --needed --noconfirm \
  stacer-bin \
  sinergia-dd-burner \
  aimp \
  iptvnator-bin \
  yaru-colors-icon-theme \
  fetch-git
 
  
# ==========================================
# 6. CONFIGURACIÓN DE APARIENCIA Y ENTORNO
# ==========================================
echo "==> Personalizando apariencia (Graphite-Dark, Yaru-MATE, Barra Inferior, Transparencia)..."

apply_user_configs() {
    local TARGET_DIR="$1"
    
    mkdir -p "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml"
    mkdir -p "$TARGET_DIR/xfce4/terminal"
    mkdir -p "$TARGET_DIR/gtk-3.0"
    mkdir -p "$TARGET_DIR/gtk-4.0"

    # 1. Configuración del Tema y los Íconos en XFCE
    cat << 'EOF' > "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
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

    # 2. Configurar Panel único en la parte inferior (p=10)
    cat << 'EOF' > "$TARGET_DIR/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panes" type="empty"/>
  <property name="panel-1" type="empty">
    <property name="position" type="string" value="p=10;x=0;y=0"/>
    <property name="length" type="uint" value="100"/>
    <property name="position-locked" type="bool" value="true"/>
    <property name="size" type="uint" value="28"/>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
      <value type="int" value="4"/>
      <value type="int" value="5"/>
      <value type="int" value="6"/>
    </property>
  </property>
</channel>
EOF

    # 3. Transparencia por defecto en XFCE Terminal
    cat << 'EOF' > "$TARGET_DIR/xfce4/terminal/terminalrc"
[Configuration]
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.85
EOF

    # 4. Extender tema oscuro a apps GTK3/GTK4
    cat << 'EOF' > "$TARGET_DIR/gtk-3.0/settings.ini"
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=Yaru-MATE
gtk-application-prefer-dark-theme=1
EOF

    cat << 'EOF' > "$TARGET_DIR/gtk-4.0/settings.ini"
[Settings]
gtk-theme-name=Graphite-Dark
gtk-icon-theme-name=Yaru-MATE
gtk-application-prefer-dark-theme=1
EOF
}

# Aplicar a /etc/skel y al usuario actual
apply_user_configs "/etc/skel/.config"
apply_user_configs "$USER_HOME/.config"
chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config"

# Configuración del tema para aplicaciones QT
if ! grep -q "QT_QPA_PLATFORMTHEME" /etc/environment; then
    echo "QT_QPA_PLATFORMTHEME=qt5ct" >> /etc/environment
fi


# ==========================================
# 7. CONFIGURACIÓN DE SYSTEM SERVICES Y GRUB
# ==========================================
echo "==> Configurando LightDM con GTK Greeter..."
sed -i 's/#\?greeter-session=.*/greeter-session=lightdm-gtk-greeter/' /etc/lightdm/lightdm.conf
systemctl enable lightdm

echo "==> Configurando GRUB para detectar otros SO..."
sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg


# ==========================================
# 8. LIMPIEZA Y REINICIO
# ==========================================
rm -rf ~/LinuxScripts

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Reiniciando el sistema en 5 segundos..."
echo "======================================================"
sleep 5
reboot
