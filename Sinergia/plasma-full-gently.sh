#!/bin/bash

# Exit on error, on unset variables, and propagate errors through pipes
set -euo pipefail

# Aviso de en qué línea falló el script, si falla
trap 'echo "==> ERROR: el script falló en la línea $LINENO (comando: $BASH_COMMAND)" >&2' ERR

# Identificar usuario real (en caso de ejecutar con sudo)
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

# Aseguramos que el keyring de pacman esté inicializado antes de importar claves
sudo pacman-key --init 2>/dev/null || true

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
sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keys.openpgp.org || \
{ sleep 5; sudo pacman-key --recv-keys 149ABD0C3A0563EE --keyserver keyserver.ubuntu.com; }

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
sudo pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com:443 || \
{ sleep 5; sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com; }
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
# 4. INSTALACIÓN DE PAQUETES OFICIALES Y CHAOTIC-AUR
# ==========================================
echo "==> Instalando Plasma, sddm, aplicaciones, dependencias y paquetes del sistema..."
sudo pacman -S --noconfirm --needed \
  plasma \
  sddm \
  sddm-kcm \
  amd-ucode \
  intel-ucode \
  okular \
  vlc \
  unrar \
  unarchiver \
  p7zip \
  firefox \
  firefox-i18n-es-ar \
  libreoffice-fresh-es \
  hunspell-es_uy \
  telegram-desktop \
  fastfetch \
  ntfs-3g \
  archlinux-tweak-tool-gtk4 \
  konsole \
  dolphin \
  kcalc \
  vlc-plugins-all \
  hardinfo2 \
  mpv \
  btop \
  gparted \
  nano \
  shelly \
  ark \
  powerdevil \
  plasma-systemmonitor \
  kwalletmanager \
  qbittorrent \
  obs-studio \
  audacity \
  ardour \
  kdenlive \
  ventoy \
  papirus-icon-theme \
  mint-l-icons \
  mint-x-icons \
  mint-y-icons \
  mate-icon-theme-faenza \
  rustdesk-bin \
  gnome-boxes \
  os-prober


# ==========================================
# 4.1 DESINSTALACIÓN DE PAQUETES NO DESEADOS
# ==========================================
echo "==> Desinstalando discover..."
for pkg in discover; do
    if pacman -Qi "$pkg" &>/dev/null; then
        echo "==> Eliminando $pkg..."
        sudo pacman -Rns --noconfirm "$pkg"
    else
        echo "==> $pkg no está instalado, se omite."
    fi
done


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
yay -S stacer-bin sinergia-dd-burner aimp iptvnator-bin yaru-colors-icon-theme fetch-git --noconfirm
  
  
# ==========================================
# 5.1 INSTALACIÓN DEL TEMA GLOBAL GENTLY-DARK-GLOBAL-6
# ==========================================
echo "==> Instalando tema global Gently-Dark-Global-6..."
THEME_BUILD_DIR=$(mktemp -d)
sudo chown -R "$REAL_USER:$REAL_USER" "$THEME_BUILD_DIR"

if sudo -u "$REAL_USER" git clone --depth 1 https://github.com/L4ki/Gently.git "$THEME_BUILD_DIR/Gently"; then
    THEME_SRC=$(find "$THEME_BUILD_DIR/Gently" -type d -iname "Gently-Dark-Global-6" | head -n1)
    if [ -n "$THEME_SRC" ]; then
        LOOKANDFEEL_DIR="$USER_HOME/.local/share/plasma/look-and-feel"
        sudo -u "$REAL_USER" mkdir -p "$LOOKANDFEEL_DIR"
        sudo -u "$REAL_USER" cp -r "$THEME_SRC" "$LOOKANDFEEL_DIR/Gently-Dark-Global-6"

        THEME_ID=$(grep -m1 "^X-KDE-PluginInfo-Name=" "$LOOKANDFEEL_DIR/Gently-Dark-Global-6/metadata.desktop" 2>/dev/null | cut -d'=' -f2)
        THEME_ID=${THEME_ID:-Gently-Dark-Global-6}

        if command -v plasma-apply-lookandfeel &>/dev/null; then
            sudo -u "$REAL_USER" plasma-apply-lookandfeel -a "$THEME_ID" || \
                echo "==> Aviso: no se pudo aplicar el tema automáticamente, quedó instalado para aplicarlo desde Configuración del Sistema."
        else
            echo "==> Aviso: plasma-apply-lookandfeel no está disponible, el tema quedó instalado para aplicarlo manualmente."
        fi
    else
        echo "==> Aviso: no se encontró la carpeta Gently-Dark-Global-6 dentro del repositorio, se omite la instalación del tema."
    fi
else
    echo "==> Aviso: no se pudo clonar el repositorio del tema Gently, se omite la instalación del tema."
fi

rm -rf "$THEME_BUILD_DIR"

# ==========================================
# 6. CONFIGURACIÓN DE SYSTEM SERVICES Y GRUB
# ==========================================
echo "==> Configurando sddm como display manager por defecto..."

# Si hay otro DM habilitado, lo deshabilitamos para evitar conflictos
for dm in entrance gdm lightdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        echo "==> Deshabilitando $dm..."
        sudo systemctl disable "$dm"
    fi
done

sudo systemctl enable sddm

echo "==> Configurando GRUB para detectar otros SO..."
if [ -f /etc/default/grub ]; then
    sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi


# ==========================================
# 6.1 DESACTIVAR KDE WALLET POR DEFECTO
# ==========================================
echo "==> Desactivando KDE Wallet por defecto para $REAL_USER..."
KWALLET_CONFIG="$USER_HOME/.config/kwalletrc"

sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"

if [ -f "$KWALLET_CONFIG" ]; then
    if grep -q "^\[Wallet\]" "$KWALLET_CONFIG"; then
        sudo -u "$REAL_USER" sed -i '/^\[Wallet\]/,/^\[/{s/^Enabled=.*/Enabled=false/}' "$KWALLET_CONFIG"
        if ! grep -A5 "^\[Wallet\]" "$KWALLET_CONFIG" | grep -q "^Enabled="; then
            sudo -u "$REAL_USER" sed -i '/^\[Wallet\]/a Enabled=false' "$KWALLET_CONFIG"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '\n[Wallet]\nEnabled=false\n' >> '$KWALLET_CONFIG'"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '[Wallet]\nEnabled=false\n' > '$KWALLET_CONFIG'"
fi


# ==========================================
# 7. LIMPIEZA Y REINICIO
# ==========================================
rm -rf "$USER_HOME/LinuxScripts"

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Display manager configurado: SDDM"
echo " KDE Wallet: desactivado por defecto"
echo " Tema global: Gently-Dark-Global-6"
echo "  
 SSSS   III   N   N  EEEEE  RRRR    GGG    III    AAA
S        I    NN  N  E      R   R  G   G    I    A   A
S        I    N N N  E      R   R  G        I    A   A
 SSS     I    N N N  EEEE   RRRR   G GGG    I    AAAAA
    S    I    N  NN  E      R R    G   G    I    A   A
    S    I    N   N  E      R  R   G   G    I    A   A
SSSS    III   N   N  EEEEE  R   R   GGG    III   A   A"
echo "======================================================"
echo "            COMUNIDAD    LINUXERA"
echo "======================================================"

read -t 15 -p "Reiniciar el sistema ahora? (s/N, auto-continúa en 15s): " respuesta || respuesta="s"
case "$respuesta" in
    [sS]|"")
        echo "==> Reiniciando..."
        sudo reboot
        ;;
    *)
        echo "==> Reinicio cancelado. Recordá reiniciar manualmente para aplicar los cambios."
        ;;
esac
