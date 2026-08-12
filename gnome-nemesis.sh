#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DEL REPOSITORIO NEMESIS_REPO (MÉTODO KIRO)
# ==========================================
echo "==> Iniciando la configuración de nemesis_repo..."

# 1.1 Crear respaldo de /etc/pacman.conf por seguridad
if [ ! -f /etc/pacman.conf.bak_nemesis ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_nemesis
fi

# 1.2 Agregar entrada temporal bootstrap si no existe [nemesis_repo]
if ! grep -q "\[nemesis_repo\]" /etc/pacman.conf; then
    echo "==> Agregando repositorio temporal para bootstrap..."
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[nemesis_repo]
Server = https://erikdubois.github.io/\$repo/\$arch
EOF'
fi

# 1.3 Sincronizar pacman para reconocer el repo temporal
sudo pacman -Sy

# 1.4 Importar y firmar la clave oficial de Kiro
echo "==> Importando clave PGP de Kiro (149ABD0C3A0563EE)..."
sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keyserver.ubuntu.com || \
sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keys.openpgp.org

sudo pacman-key --lsign-key 149ABD0C3A0563EE

# 1.5 Instalar kiro-keyring y kiro-mirrorlist
echo "==> Instalando kiro-keyring y kiro-mirrorlist..."
sudo pacman -Sy --needed kiro-keyring kiro-mirrorlist --noconfirm

# 1.6 Reemplazar la línea 'Server' por 'Include' con kiro-mirrorlist
echo "==> Actualizando /etc/pacman.conf para usar la kiro-mirrorlist..."
sudo sed -i 's|Server = https://erikdubois.github.io/\$repo/\$arch|Include = /etc/pacman.d/kiro-mirrorlist|g' /etc/pacman.conf

# 1.7 Sincronizar pacman final con la nueva mirrorlist
sudo pacman -Sy

# ==========================================
# 2. INSTALACIÓN DE PAQUETES DE PACMAN
# ==========================================
echo "==> Instalando entorno GNOME y aplicaciones..."
sudo pacman -S gnome-shell gnome-tweaks --noconfirm

sudo pacman -S gdm gnome-characters gnome-backgrounds gnome-calendar gnome-clocks gnome-connections gnome-font-viewer gnome-logs gnome-maps gnome-remote-desktop gnome-color-manager gnome-control-center gnome-disk-utility gnome-keyring gnome-menus gnome-session gnome-settings-daemon gnome-shell-extensions gnome-system-monitor gnome-text-editor gnome-user-docs gnome-user-share gvfs-dnssd gvfs-wsdd loupe alacritty rygel sushi tecla tracker3-miners xdg-desktop-portal xdg-user-dirs-gtk yelp baobab evince grilo-plugins gvfs gvfs-afc gvfs-goa gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb nautilus gnome-terminal pacman-contrib gnome-browser-connector amd-ucode intel-ucode vlc qbittorrent ark unrar p7zip firefox firefox-i18n-es-ar libreoffice-fresh-es hunspell-es_uy telegram-desktop fastfetch --noconfirm

sudo pacman -S ntfs-3g os-prober --noconfirm

# ==========================================
# 3. INSTALACIÓN DE YAY Y PAQUETES AUR
# ==========================================
echo "==> Asegurando base-devel e instalando YAY..."
sudo pacman -S --needed base-devel git --noconfirm

rm -rf yay
git clone https://aur.archlinux.org/yay.git
cd yay || exit
makepkg -si --noconfirm
cd ..
rm -rf yay

echo "==> Instalando paquetes desde AUR..."
yay -S stacer-bin gnome-shell-extension-dash2dock-lite gnome-shell-extension-compiz-alike-magic-lamp-effect-git gnome-shell-extension-compiz-windows-effect-git gnome-shell-extension-arc-menu-git archlinux-tweak-tool-git --noconfirm

# ==========================================
# 4. CONFIGURACIÓN DEL SISTEMA Y GRUB
# ==========================================
echo "==> Habilitando os-prober en GRUB..."
sudo sed -i.bak "63s/.*/GRUB_DISABLE_OS_PROBER=\"false\"/" /etc/default/grub

echo "==> Limpiando carpeta del script..."
rm -rf ~/LinuxScripts

echo "==> Habilitando servicio GDM..."
sudo systemctl enable gdm.service

echo "==> Actualizando GRUB..."
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Proceso finalizado. Reiniciando el sistema en 5 segundos..."
sleep 5
reboot
