 #! /bin/bash
sudo pacman -S sudo pacman-key --recv-key  D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B --noconfirm

sudo pacman -S sudo pacman-key --lsign-key  D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B --noconfirm

sudo pacman -S sudo pacman -Sy --noconfirm

sudo pacman -S sudo pacman -S tde-meta --noconfirm

sudo pacman -S amd-ucode intel-ucode okular vlc  ark unrar p7zip grub-customizer sudo chromium firefox firefox-i18n-es-ar libreoffice-fresh-es hunspell-es_uy telegram-desktop zsh zsh-completions neofetch --noconfirm

sudo pacman -S ntfs-3g os-prober --noconfirm
sudo sed -i.bak "63s/.*/GRUB_DISABLE_OS_PROBER="false"/" /etc/default/grub

rm -rf ~/LinuxScripts

sudo systemctl enable tdm.service

grub-mkconfig -o /boot/grub/grub.cfg

reboot
