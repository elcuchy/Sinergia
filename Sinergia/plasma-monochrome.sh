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
yay -S stacer-bin sinergia-dd-burner iptvnator-bin yaru-colors-icon-theme fetch-git --noconfirm
  
  
# ==========================================
# 5.1 INSTALACIÓN DEL TEMA MONOCHROME (GLOBAL + SPLASH + SDDM) Y ÁCONOS YARU-GREY
# ==========================================
echo "==> Asegurando wget para el instalador de Monochrome..."
sudo pacman -S --needed wget --noconfirm

echo "==> Instalando tema Monochrome (KDE)..."
THEME_BUILD_DIR=$(mktemp -d)
sudo chown -R "$REAL_USER:$REAL_USER" "$THEME_BUILD_DIR"

if sudo -u "$REAL_USER" git clone --depth 1 https://github.com/pwyde/monochrome-kde.git "$THEME_BUILD_DIR/monochrome-kde"; then

    # El propio instalador del proyecto copia tema global, plasma theme, aurorae,
    # color scheme, kvantum, konsole y yakuake a $HOME automáticamente
    sudo -u "$REAL_USER" bash -c "cd '$THEME_BUILD_DIR/monochrome-kde' && bash install.sh --install" || \
        echo "==> Aviso: install.sh de Monochrome devolvió un error, se intentará continuar igual."

    # SDDM: el proyecto NO lo instala automáticamente, hay que copiarlo a mano con sudo
    SDDM_SRC=$(find "$THEME_BUILD_DIR/monochrome-kde" -type d -ipath "*sddm/themes/monochrome" | head -n1)
    if [ -n "$SDDM_SRC" ]; then
        sudo mkdir -p /usr/share/sddm/themes
        sudo rm -rf /usr/share/sddm/themes/monochrome
        sudo cp -r "$SDDM_SRC" /usr/share/sddm/themes/monochrome
        echo "==> Tema SDDM Monochrome copiado a /usr/share/sddm/themes/monochrome"

        sudo mkdir -p /etc/sddm.conf.d
        sudo bash -c "printf '[Theme]\nCurrent=monochrome\n' > /etc/sddm.conf.d/kde_theme.conf"
        echo "==> SDDM configurado para usar el tema Monochrome como pantalla de inicio de sesión."
    else
        echo "==> Aviso: no se encontró la carpeta del tema SDDM dentro del repositorio, se omite ese paso."
    fi

    # Detectar el Tema Global instalado para aplicarlo/fijarlo por defecto
    LOOKANDFEEL_DIR="$USER_HOME/.local/share/plasma/look-and-feel"
    THEME_SRC=$(find "$LOOKANDFEEL_DIR" -maxdepth 1 -type d -iname "*onochrome*" 2>/dev/null | head -n1)
    echo "==> Carpeta del tema global detectada: ${THEME_SRC:-(ninguna)}"

    if [ -n "$THEME_SRC" ]; then
        METADATA_FILE="$THEME_SRC/metadata.desktop"
        [ -f "$METADATA_FILE" ] || METADATA_FILE="$THEME_SRC/metadata.json"

        THEME_ID=$(grep -m1 -E "\"?X-KDE-PluginInfo-Name\"?[=:]" "$METADATA_FILE" 2>/dev/null | sed -E 's/.*[=:]\s*"?([^",]+)"?.*/\1/' || true)
        THEME_ID=$(echo "$THEME_ID" | tr -d '[:space:]')
        THEME_ID=${THEME_ID:-$(basename "$THEME_SRC")}
        echo "==> ID del tema global a aplicar: $THEME_ID"

        # Aplicar en vivo si hay herramienta disponible (modo offscreen, sin requerir sesión gráfica)
        if command -v plasma-apply-lookandfeel &>/dev/null; then
            USER_UID=$(id -u "$REAL_USER")
            RUNTIME_DIR="/run/user/$USER_UID"
            if [ ! -d "$RUNTIME_DIR" ]; then
                RUNTIME_DIR=$(sudo -u "$REAL_USER" mktemp -d)
            fi
            sudo -u "$REAL_USER" env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$RUNTIME_DIR" \
                plasma-apply-lookandfeel -a "$THEME_ID" || \
                echo "==> Aviso: plasma-apply-lookandfeel devolvió un error, se usará el respaldo directo sobre kdeglobals."
        else
            echo "==> Aviso: plasma-apply-lookandfeel no está disponible, se usará el respaldo directo sobre kdeglobals."
        fi

        # Respaldo: forzar el tema global y el splash directamente en los archivos de config,
        # por si el paso anterior no tuvo efecto por falta de sesión gráfica activa
        KDEGLOBALS="$USER_HOME/.config/kdeglobals"
        sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
        if [ -f "$KDEGLOBALS" ] && grep -q "^\[KDE\]" "$KDEGLOBALS"; then
            if grep -q "^LookAndFeelPackage=" "$KDEGLOBALS"; then
                sudo -u "$REAL_USER" sed -i "s|^LookAndFeelPackage=.*|LookAndFeelPackage=$THEME_ID|" "$KDEGLOBALS"
            else
                sudo -u "$REAL_USER" sed -i "/^\[KDE\]/a LookAndFeelPackage=$THEME_ID" "$KDEGLOBALS"
            fi
        else
            sudo -u "$REAL_USER" bash -c "printf '\n[KDE]\nLookAndFeelPackage=%s\n' '$THEME_ID' >> '$KDEGLOBALS'"
        fi

        KSPLASHRC="$USER_HOME/.config/ksplashrc"
        if [ -f "$KSPLASHRC" ] && grep -q "^\[KSplash\]" "$KSPLASHRC"; then
            if grep -q "^Theme=" "$KSPLASHRC"; then
                sudo -u "$REAL_USER" sed -i "s|^Theme=.*|Theme=$THEME_ID|" "$KSPLASHRC"
            else
                sudo -u "$REAL_USER" sed -i "/^\[KSplash\]/a Theme=$THEME_ID" "$KSPLASHRC"
            fi
        else
            sudo -u "$REAL_USER" bash -c "printf '\n[KSplash]\nTheme=%s\n' '$THEME_ID' >> '$KSPLASHRC'"
        fi
        echo "==> Tema $THEME_ID fijado como Global Theme y Splash Screen por defecto."
    else
        echo "==> Aviso: no se encontró el Tema Global de Monochrome instalado, se omite fijarlo por defecto."
    fi
else
    echo "==> Aviso: no se pudo clonar el repositorio de Monochrome, se omite la instalación del tema."
fi

rm -rf "$THEME_BUILD_DIR"

# ==========================================
# 5.2 ICONOS YARU-GREY POR DEFECTO
# ==========================================
echo "==> Configurando iconos Yaru-Grey por defecto..."
ICON_DIR=$(find /usr/share/icons "$USER_HOME/.local/share/icons" -maxdepth 1 -type d -iname "*yaru*grey*" 2>/dev/null | head -n1)
echo "==> Carpeta de iconos detectada: ${ICON_DIR:-(ninguna)}"

if [ -n "$ICON_DIR" ]; then
    ICON_THEME_ID=$(basename "$ICON_DIR")
    KDEGLOBALS="$USER_HOME/.config/kdeglobals"
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
    if [ -f "$KDEGLOBALS" ] && grep -q "^\[Icons\]" "$KDEGLOBALS"; then
        if grep -q "^Theme=" "$KDEGLOBALS"; then
            sudo -u "$REAL_USER" sed -i "0,/^\[Icons\]/! {0,/^Theme=/ s|^Theme=.*|Theme=$ICON_THEME_ID|}" "$KDEGLOBALS"
        else
            sudo -u "$REAL_USER" sed -i "/^\[Icons\]/a Theme=$ICON_THEME_ID" "$KDEGLOBALS"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '\n[Icons]\nTheme=%s\n' '$ICON_THEME_ID' >> '$KDEGLOBALS'"
    fi
    echo "==> Icon theme $ICON_THEME_ID fijado como icono por defecto."
else
    echo "==> Aviso: no se encontró ninguna variante Yaru-Grey instalada, se omite fijar el icon theme."
fi

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
echo " Tema global: Monochrome
 Icon theme: Yaru-Grey
 Pantalla de bienvenida (splash): Monochrome
 Pantalla de inicio de sesión (SDDM): Monochrome"
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
