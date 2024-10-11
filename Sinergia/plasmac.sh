 #! /bin/bash


sudo pacman -S plasma-desktop plasma-pa plasma-nm kscreen kde-gtk-config wget gtk3 breeze-gtk dolphin ark kwalletmanager gwenview kate kcalc konsole okular spectable unrar p7zip gparted plasma-systemmonitor libappimage gst-libav ffmpeg4.4 noto-fonts-emoji --noconfirm --needed
clear

echo -e "Prefieres tener un gestor de inicio para iniciar KDE? Por defecto sddm. (1) Prefiero iniciar con el startplasma-wayland desde la consola"; read -p "" gestordeinicio
if [ "${gestordeinicio^}" = "1" ]; then
echo -e "opcion. (1) Prefiero iniciar con el startplasma-wayland desde la consola"
else
sudo pacman -S sddm sddm-kcm  --noconfirm --needed;  systemctl enable sddm.service
fi
clear

sudo pacman -S firewalld --noconfirm --needed; systemctl enable firewalld.service
clear

echo -e "Prefieres tener algun otro navegador por defecto en lugar de Firefox. (1) Falkon de KDE. (2) Ninguno por defecto"; read -p "" navegador
if [ "${navegador^}" = "2" ]; then
echo -e "opcion. (2) Ninguno por defecto"
elif [ "${navegador^}" = "1" ]; then
sudo pacman -S falkon --noconfirm --needed
else
sudo pacman -S firefox firefox-i18n-es-es --noconfirm --needed
fi
clear

sudo wget https://appimages.libreitalia.org/LibreOffice-fresh.standard-x86_64.AppImage
clear

sudo pacman -S telegram-desktop --noconfirm --needed

sudo pacman -S git go --noconfirm --needed
git clone https://aur.archlinux.org/yay.git; cd yay; makepkg -si; cd
clear

echo -e "Necesitas os-prober para un dualboot. (1) No, no lo necesito"; read -p "" dualboot
if [ "${dualboot^}" = "1" ]; then
echo -e "opcion. (1) No, no lo necesito"
else
sudo pacman -S ntfs-3g os-prober --noconfirm --needed
fi
clear

reboot

