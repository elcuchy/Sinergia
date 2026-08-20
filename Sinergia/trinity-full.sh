#!/bin/bash

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
  tde-meta \
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
  os-prober

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
