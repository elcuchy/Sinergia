 #! /bin/bash

sudo pacman -S sudo pacman -S gnome --noconfirm

sudo pacman -S gdm gnome-characters gnome-color-manager gnome-control-center gnome-disk-utility gnome-keyring gnome-menus gnome-session gnome-settings-daemon gnome-shell grilo-plugins gvfs gvfs-afc gvfs-goa gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb nautilus gnome-terminal pacman-contrib amd-ucode intel-ucode okular vlc qbittorrent ark unrar p7zip grub-customizer firefox firefox-i18n-es-ar kdenlive obs-studio audacity libreoffice-fresh-es hunspell-es_uy telegram-desktop audacious gimp zsh zsh-completions --noconfirm

git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd ..

yay -S appimagelauncher-bin stacer-bin gnome-shell-extension-dash-to-dock arch-update gnome-shell-extension-burn-my-windows gnome-shell-extension-compiz-alike-magic-lamp-effect-git gnome-shell-extension-compiz-windows-effect-git gnome-shell-extension-coverflow-alt-tab gnome-shell-extension-desktop-cube gnome-shell-extension-arc-menu-git archlinux-tweak-tool-git --noconfirm
sudo pacman -S ntfs-3g os-prober --noconfirm
sudo sed -i.bak "63s/.*/GRUB_DISABLE_OS_PROBER="false"/" /etc/default/grub

rm -rf ~/LinuxScripts



sudo systemctl enable gdm.service

grub-mkconfig -o /boot/grub/grub.cfg

reboot
