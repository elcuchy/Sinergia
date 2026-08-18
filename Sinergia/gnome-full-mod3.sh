#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO Y PACMAN
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
fi

echo "==> Activando ILoveCandy y descargas paralelas en pacman.conf..."

# Añadir ILoveCandy directamente debajo de [options]
if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi

# Activar descargas paralelas
if grep -q "#ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i 's/#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf
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
# 4. INSTALACIÓN DE PAQUETES DE PACMAN
# ==========================================
echo "==> Instalando entorno GNOME y aplicaciones..."
sudo pacman -S gnome-shell gnome-tweaks --noconfirm

sudo pacman -S gdm gnome-characters gnome-backgrounds gnome-calendar gnome-clocks gnome-connections gnome-font-viewer gnome-logs gnome-maps gnome-remote-desktop gnome-color-manager gnome-control-center gnome-disk-utility gnome-keyring gnome-menus gnome-session gnome-settings-daemon gnome-shell-extensions gnome-system-monitor gnome-text-editor gnome-user-docs gnome-user-share gvfs-dnssd gvfs-wsdd loupe alacritty rygel sushi tecla tracker3-miners xdg-desktop-portal xdg-user-dirs-gtk yelp baobab evince grilo-plugins gvfs gvfs-afc gvfs-goa gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb nautilus gnome-terminal-transparency pacman-contrib gnome-browser-connector amd-ucode intel-ucode vlc qbittorrent ark unrar p7zip firefox firefox-i18n-es-ar libreoffice-fresh-es hunspell-es_uy telegram-desktop fastfetch archlinux-tweak-tool-gtk4 gnome-shell-extension-arch-update gnome-shell-extension-dash-to-dock pamac-aur ttf-firacode-nerd gedit hardinfo2 gnome-boxes okular decibels snapshot gnome-font-viewer mpv obs-studio audacious audacity ardour gparted kdenlive ventoy btop papirus-icon-theme nano dconf-editor --noconfirm

sudo pacman -S ntfs-3g os-prober --noconfirm


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
yay -S stacer-bin gnome-shell-extension-dash2dock-lite gnome-shell-extension-compiz-alike-magic-lamp-effect-git gnome-shell-extension-compiz-windows-effect-git gnome-shell-extension-arc-menu-git gnome-shell-extension-astra-monitor gnome-shell-extension-burn-my-windows gnome-shell-extension-coverflow-alt-tab-git sinergia-dd-burner aimp iptvnator-bin yaru-colors-icon-theme --noconfirm


# ==========================================
# 6. CONFIGURACIÓN GLOBAL DE DCONF / GNOME
# ==========================================
echo "==> Aplicando configuración por defecto del sistema mediante dconf..."

# Asegurar directorios de dconf
sudo mkdir -p /etc/dconf/profile
sudo mkdir -p /etc/dconf/db/local.d/

# Perfil de dconf
sudo bash -c 'cat << EOF > /etc/dconf/profile/user
user-db:user
system-db:local
EOF'

# Valores por defecto para el entorno GNOME, Extensiones y GNOME Terminal
sudo bash -c 'cat << EOF > /etc/dconf/db/local.d/00-system-defaults
[org/gnome/shell]
enabled-extensions=["magic-lamp-effect@hermes83.github.com", "compiz-windows-effect@hermes83.github.com", "arcmenu@arcmenu.com", "AstraMonitor@AstraMonitor", "burn-my-windows@schneegans.github.com", "CoverflowAltTab@palatis.blogspot.com", "arch-update@RaphaelRochet", "dash-to-dock@micxgx.gmail.com"]

[org/gnome/desktop/interface]
color-scheme="prefer-dark"
gtk-theme="Adwaita-dark"
accent-color="green"
icon-theme="Yaru-MATE"

[org/gnome/desktop/wm/preferences]
button-layout="appmenu:minimize,maximize,close"

[org/gnome/shell/extensions/arcmenu]
menu-shortcut=["<Control>space"]
custom-menu-button-icon-name="arch-linux-symbolic"
arc-menu-icon="arch-linux-symbolic"
override-menu-button-color=true
custom-menu-button-color="rgb(0,186,255)"

[org/gnome/shell/extensions/dash-to-dock]
dash-max-icon-size=28
icon-size-fixed=true
transparency-mode="DYNAMIC"

[org/gnome/shell/extensions/burn-my-windows]
active-profile=""
open-window-effect="hexagon.glsl"
close-window-effect="hexagon.glsl"

[org/gnome/terminal/profiles:]
default="b1d3e78f-16f2-4e0d-b6e9-2a0546e45f5e"
list=["b1d3e78f-16f2-4e0d-b6e9-2a0546e45f5e"]

[org/gnome/terminal/legacy/profiles:/:b1d3e78f-16f2-4e0d-b6e9-2a0546e45f5e]
use-theme-transparent-background=false
use-transparent-background=true
background-transparency-percent=15
EOF'

# Actualizar base de datos del sistema dconf
sudo dconf update


# ==========================================
# 7. CONFIGURACIÓN DEL SISTEMA Y GRUB
# ==========================================
echo "==> Habilitando os-prober en GRUB..."
sudo sed -i.bak "63s/.*/GRUB_DISABLE_OS_PROBER=\"false\"/" /etc/default/grub

echo "==> Limpiando carpeta del script..."
rm -rf ~/LinuxScripts

echo "==> Habilitando servicio GDM..."
sudo systemctl enable gdm.service

echo "==> Actualizando GRUB..."
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Proceso finalizado con éxito. Reiniciando el sistema en 5 segundos..."
sleep 5
reboot
