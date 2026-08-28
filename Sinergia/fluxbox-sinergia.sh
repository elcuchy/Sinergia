#!/bin/bash

# Detener la ejecución si ocurre un error
set -e

# Identificar al usuario real si el script se ejecuta con sudo
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
sudo pacman -S --needed kiro-keyring kiro-mirrorlist --noconfirm

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

# Sincronizar bases de datos tras añadir todos los repositorios
sudo pacman -Sy


# ==========================================
# 4. INSTALACIÓN DE PAQUETES DEL SISTEMA, THUNAR, FLUXBOX Y TEMAS GTK
# ==========================================
echo "==> Instalando paquetes base, Thunar, Fluxbox y software del sistema..."
sudo pacman -S --noconfirm --needed \
  fluxbox \
  menumaker \
  picom \
  arc-gtk-theme \
  papirus-icon-theme \
  lxappearance \
  thunar \
  thunar-archive-plugin \
  thunar-volman \
  tumbler \
  xorg-server \
  xorg-xinit \
  xorg-xmessage \
  feh \
  alacritty \
  dmenu \
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
  lightdm \
  lightdm-gtk-greeter \
  os-prober


# ==========================================
# 5. INSTALACIÓN DE YAY Y PAQUETES AUR
# ==========================================
echo "==> Asegurando base-devel e instalando YAY..."
sudo pacman -S --needed base-devel git --noconfirm

# Compilar YAY con el usuario no-root
BUILD_DIR=$(mktemp -d)
sudo chown -R "$REAL_USER:$REAL_USER" "$BUILD_DIR"

sudo -u "$REAL_USER" bash -c "
  git clone https://aur.archlinux.org/yay.git '$BUILD_DIR/yay'
  cd '$BUILD_DIR/yay'
  makepkg -si --noconfirm
"
rm -rf "$BUILD_DIR"

echo "==> Instalando paquetes de AUR con YAY..."
sudo -u "$REAL_USER" yay -S --needed stacer-bin --noconfirm


# ==========================================
# 6. CONFIGURACIÓN DEL TEMA GTK Y DE ICONOS (CORREGIDO)
# ==========================================
echo "==> Aplicando configuración visual GTK (Arc-Dark + Papirus)..."

setup_gtk_theme() {
    local TARGET_HOME="$1"
    local TARGET_USER="$2"

    # Asegurar directorio de configuración
    mkdir -p "$TARGET_HOME/.config/gtk-3.0"

    # GTK 2.0
    cat << 'EOF' > "$TARGET_HOME/.gtkrc-2.0"
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Noto Sans 10"
gtk-cursor-theme-name="Adwaita"
EOF

    # GTK 3.0
    cat << 'EOF' > "$TARGET_HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
EOF

    # Ajustar permisos para el usuario
    if [ "$TARGET_USER" != "root" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gtkrc-2.0" "$TARGET_HOME/.config"
    fi
}

# Aplicar al usuario actual
setup_gtk_theme "$USER_HOME" "$REAL_USER"

# Configurar plantilla para /etc/skel
sudo mkdir -p /etc/skel/.config/gtk-3.0
setup_gtk_theme "/etc/skel" "root"


# ==========================================
# 7. CONFIGURACIÓN DE FLUXBOX Y MENÚ DE APLICACIONES
# ==========================================
echo "==> Estructurando configuración de Fluxbox..."

setup_fluxbox_user() {
    local TARGET_HOME="$1"
    local TARGET_USER="$2"
    local FLUX_DIR="$TARGET_HOME/.fluxbox"

    sudo -u "$TARGET_USER" mkdir -p "$FLUX_DIR"

    # Generar menú dinámico de aplicaciones
    sudo -u "$TARGET_USER" mmaker -f FluxBox

    # Archivo de inicio (Startup)
    cat << 'EOF' | sudo tee "$FLUX_DIR/startup" > /dev/null
#!/bin/sh

# Iniciar compositor visual (sombras y transparencias)
picom -b &

# Fondo de pantalla neutro
feh --bg-fill /usr/share/backgrounds/archlinux/simple.png 2>/dev/null || xsetroot -solid "#1e1e2e" &

# Iniciar Ulauncher en segundo plano
ulauncher --hide-window &

# Ejecutar Fluxbox
exec fluxbox
EOF

    sudo chmod +x "$FLUX_DIR/startup"
    sudo chown -R "$TARGET_USER:$TARGET_USER" "$FLUX_DIR"
}

setup_fluxbox_user "$USER_HOME" "$REAL_USER"

sudo mkdir -p /etc/skel/.fluxbox
sudo mmaker -f FluxBox --output /etc/skel/.fluxbox/menu


# ==========================================
# 8. CONFIGURACIÓN DE ENTORNO X11 (.xinitrc)
# ==========================================
echo "==> Configurando .xinitrc para iniciar Fluxbox con startx..."

create_xinitrc() {
    local TARGET_FILE="$1"
    cat << 'EOF' | sudo tee "$TARGET_FILE" > /dev/null
#!/bin/sh

userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

if [ -f $sysresources ]; then xrdb -merge $sysresources; fi
if [ -f $sysmodmap ]; then xmodmap $sysmodmap; fi
if [ -f "$userresources" ]; then xrdb -merge "$userresources"; fi
if [ -f "$usermodmap" ]; then xmodmap "$usermodmap"; fi

exec startfluxbox
EOF
    sudo chmod +x "$TARGET_FILE"
}

create_xinitrc "/etc/skel/.xinitrc"
create_xinitrc "$USER_HOME/.xinitrc"
sudo chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xinitrc"


# ==========================================
# 9. CONFIGURACIÓN DE SERVICIOS Y GRUB
# ==========================================
echo "==> Habilitando LightDM..."
sudo systemctl enable lightdm.service

echo "==> Configurando GRUB para detectar otros SO..."
if [ -f /etc/default/grub ]; then
    sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi


# ==========================================
# 10. LIMPIEZA Y REINICIO
# ==========================================
rm -rf ~/LinuxScripts

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Reiniciando el sistema en 5 segundos..."
echo "======================================================"
sleep 5
sudo reboot
