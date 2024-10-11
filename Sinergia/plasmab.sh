 #! /bin/bash


sudo pacman -S plasma-desktop plasma-pa plasma-nm kscreen kde-gtk-config wget gtk3 breeze-gtk dolphin ark kwalletmanager gwenview kate kcalc konsole okular spectable unrar p7zip gparted plasma-systemmonitor libappimage gst-libav ffmpeg4.4 noto-fonts-emoji --noconfirm --needed
clear

echo -e "Prefieres tener un gestor de inicio para iniciar KDE? Por defecto sddm. (1) Prefiero iniciar con el startplasma-wayland desde la consola"; read -s -p "" gestordeinicio
if [ "${gestordeinicio^}" = "1" ]; then
echo -e "opcion. (1) Prefiero iniciar con el startplasma-wayland desde la consola"
else
sudo pacman -S sddm sddm-kcm  --noconfirm --needed;  systemctl enable sddm.service
fi
clear

sudo pacman -S firewalld --noconfirm --needed; systemctl enable firewalld.service
clear

echo -e "Prefieres tener algun otro navegador por defecto en lugar de Firefox. (1) Falkon de KDE. (2) Ninguno por defecto"; read -s -p "" navegador
if [ "${navegador^}" = "2" ]; then
echo -e "opcion. (2) Ninguno por defecto"
else [ "${navegador^}" = "1" ]; then
sudo pacman -S falkon --noconfirm --needed
else
sudo pacman -S firefox firefox-i18n-es-es --noconfirm --needed
fi
clear

wget https://appimages.libreitalia.org/LibreOffice-fresh.standard-x86_64.AppImage
clear

wget https://objects.githubusercontent.com/github-production-release-asset-2e65be/356231211/29b3bad8-23a3-474c-a6ee-421c71260627?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAVCODYLSA53PQK4ZA%2F20240330%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20240330T000212Z&X-Amz-Expires=300&X-Amz-Signature=ceb1a9fb6cb42e7bbd465ccc6e38d103a8ce8d44b58201961110faf837672933&X-Amz-SignedHeaders=host&actor_id=0&key_id=0&repo_id=356231211&response-content-disposition=attachment%3B filename%3DTelegram-A-x86_64.AppImage&response-content-type=application%2Foctet-stream
clear

sudo pacman -S git go --noconfirm --needed
git clone https://aur.archlinux.org/yay.git; cd yay; makepkg -si; cd
clear

echo -e "Necesitas os-prober para un dualboot. (1) No, no lo necesito"; read -s -p "" dualboot
if [ "${dualboot^}" = "1" ]; then
echo -e "opcion. (1) No, no lo necesito"
else
sudo pacman -S ntfs-3g os-prober --noconfirm --needed
fi
clear

reboot

