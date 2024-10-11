 #! /bin/bash

sudo pacman -S plasma-desktop plasma-pa powerdevil plasma-nm kscreen sddm sddm-kcm --noconfirm

sudo pacman -S kwalletmanager kdeplasma-addons spectacle dolphin konsole gwenview kate okular vlc qbittorrent ark unrar p7zip unarchiver partitionmanager plasma-systemmonitor kcalc kde-gtk-config breeze-gtk plasma-framework5 kinfocenter --noconfirm

sudo pacman -S firefox firefox-i18n-es-ar kdenlive obs-studio libreoffice-fresh-es hunspell-es_ar telegram-desktop --noconfirm

git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd ..

sudo pacman -S ntfs-3g os-prober --noconfirm

cp ~/Sinergia/kwalletrc ~/.config/kwalletrc

sudo systemctl enable sddm.service

reboot
