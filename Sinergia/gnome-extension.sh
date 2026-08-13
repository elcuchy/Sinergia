#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
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

# 3.1 Recibir y firmar clave primaria de Chaotic-AUR
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || \
sudo pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com:443
sudo pacman-key --lsign-key 3056513887B78AEB

# 3.2 Instalar los paquetes del llavero y lista de espejos de Chaotic-AUR
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

# 3.3 Añadir la sección de Chaotic-AUR a pacman.conf si no existe
if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo "==> Agregando [chaotic-aur] a pacman.conf..."
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF'
fi

# 3.4 Sincronizar todos los repositorios agregados
echo "==> Actualizando la base de datos de repositorios..."
sudo pacman -Sy


# ==========================================
# 4. INSTALACIÓN DE PAQUETES DE PACMAN
# ==========================================
echo "==> Instalando entorno GNOME y aplicaciones..."
sudo pacman -S gnome-shell gnome-tweaks --noconfirm

sudo pacman -S gdm gnome-characters gnome-backgrounds gnome-calendar gnome-clocks gnome-connections gnome-font-viewer gnome-logs gnome-maps gnome-remote-desktop gnome-color-manager gnome-control-center gnome-disk-utility gnome-keyring gnome-menus gnome-session gnome-settings-daemon gnome-shell-extensions gnome-system-monitor gnome-text-editor gnome-user-docs gnome-user-share gvfs-dnssd gvfs-wsdd loupe alacritty rygel sushi tecla tracker3-miners xdg-desktop-portal xdg-user-dirs-gtk yelp baobab evince grilo-plugins gvfs gvfs-afc gvfs-goa gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb nautilus gnome-terminal pacman-contrib gnome-browser-connector amd-ucode intel-ucode vlc qbittorrent ark unrar p7zip firefox firefox-i18n-es-ar libreoffice-fresh-es hunspell-es_uy telegram-desktop fastfetch-git archlinux-tweak-tool-gtk4 pamac-aur gnome-shell-extension-compiz-windows-effect-git gnome-shell-extension-arch-update gnome-shell-extension-dash-to-dock --noconfirm

sudo pacman -S ntfs-3g os-prober --noconfirm


# ==========================================
# 5. COMPILACIÓN E INSTALACIÓN DESDE AUR (YAY Y ASTRA MONITOR)
# ==========================================
echo "==> Asegurando base-devel e instalando YAY..."
sudo pacman -S --needed base-devel git --noconfirm

# Instalación de YAY
rm -rf yay
git clone https://aur.archlinux.org/yay.git
cd yay || exit
makepkg -si --noconfirm
cd ..
rm -rf yay

# Lista de extensiones del AUR a compilar e instalar
EXTENSIONES=(
  "gnome-shell-extension-astra-monitor"
  "gnome-shell-extension-dash-to-dock"
  "gnome-shell-extension-compiz-alike-magic-lamp-effect-git"
  "gnome-shell-extension-arc-menu-git"
  "gnome-shell-extension-burn-my-windows"
  "gnome-shell-extension-coverflow-alt-tab"
  "gnome-shell-extension-desktop-cube"
)

echo "==> Iniciando instalación masiva de extensiones GNOME..."
echo "----------------------------------------------------"

# 1. Bucle para clonar, compilar e instalar cada paquete del AUR
for ext in "${EXTENSIONES[@]}"; do
  echo "==> Procesando: $ext..."
  
  # Limpieza previa por si existe la carpeta
  rm -rf "$ext"
  
  if git clone "https://aur.archlinux.org/${ext}.git"; then
    cd "$ext" || exit 1
    makepkg -si --noconfirm
    cd ..
    rm -rf "$ext"
    echo "✔ $ext compilada e instalada con éxito."
  else
    echo "✖ Error al clonar $ext de la AUR."
  fi
  
  echo "----------------------------------------------------"
done

# 2. Habilitar automáticamente todas las extensiones instaladas
echo "==> Activando extensiones en GNOME Shell..."

EXTENSION_IDS=(
  "astra-monitor@astra-monitor"
  "dash-to-dock@micxgx.gmail.com"
  "compiz-alike-magic-lamp-effect@hermes83.github.com"
  "arcmenu@arcmenu.com"
  "burn-my-windows@schneegans.github.com"
  "CoverflowAltTab@palacaze.fr"
  "desktop-cube@johannesjo.github.com"
)

for id in "${EXTENSION_IDS[@]}"; do
  gnome-extensions enable "$id" 2>/dev/null && echo "✔ Activada: $id" || echo "⚠ No se pudo activar automáticamente: $id"
done

echo "----------------------------------------------------"
echo "==> ¡Proceso finalizado!"

# Instalación del resto de paquetes desde AUR/Chaotic
echo "==> Instalando paquetes adicionales..."
yay -S stacer-bin --noconfirm


# ==========================================
# 6. CONFIGURACIÓN DEL SISTEMA Y GRUB
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
