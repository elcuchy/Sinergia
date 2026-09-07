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
  yakuake \
  kvantum \
  kvantum-qt5 \
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
  os-prober \
  plasma-sdk \
  unzip


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
yay -S stacer-bin sinergia-dd-burner iptvnator-bin yamis-icon-theme-git fetch-git --noconfirm

# ==========================================
# 5.1 INSTALAR Y APLICAR SILVERY-DARK-GLOBAL-6
# ==========================================
echo "==> Instalando tema global Silvery-Dark-Global-6..."

SILVERY_ID="org.kde.silvery-dark-global-6"
LAF_DIR="$USER_HOME/.local/share/plasma/look-and-feel"
SILVERY_EXTRACTED="$LAF_DIR/silvery-dark-global-6"

sudo -u "$REAL_USER" mkdir -p "$LAF_DIR"

# Descargar desde GitHub (repositorio oficial de L4ki)
if [ ! -d "$SILVERY_EXTRACTED" ]; then
    echo "==> Descargando Silvery-Dark-Global-6 desde GitHub..."
    sudo -u "$REAL_USER" git clone https://github.com/L4ki/Silvery-Dark-Global-6.git "$SILVERY_EXTRACTED" || {
        echo "==> Aviso: No se pudo clonar desde GitHub, se omite este paso."
    }
fi

# Aplicar el tema global
USER_UID=$(id -u "$REAL_USER")
RUNTIME_DIR="/run/user/$USER_UID"
if [ ! -d "$RUNTIME_DIR" ]; then
    RUNTIME_DIR=$(sudo -u "$REAL_USER" mktemp -d)
fi

echo "==> Aplicando Silvery-Dark-Global-6 como Look and Feel..."
if command -v plasma-apply-lookandfeel &>/dev/null; then
    sudo -u "$REAL_USER" env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$RUNTIME_DIR" \
        plasma-apply-lookandfeel -a "$SILVERY_ID" 2>/dev/null || \
        echo "==> Aviso: plasma-apply-lookandfeel devolvió un error, se usará el respaldo directo sobre kdeglobals."
else
    echo "==> Aviso: plasma-apply-lookandfeel no está disponible."
fi

# Respaldo: forzar en kdeglobals
KDEGLOBALS="$USER_HOME/.config/kdeglobals"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if [ -f "$KDEGLOBALS" ] && grep -q "^\[KDE\]" "$KDEGLOBALS"; then
    if grep -q "^LookAndFeelPackage=" "$KDEGLOBALS"; then
        sudo -u "$REAL_USER" sed -i "s|^LookAndFeelPackage=.*|LookAndFeelPackage=$SILVERY_ID|" "$KDEGLOBALS"
    else
        sudo -u "$REAL_USER" sed -i "/^\[KDE\]/a LookAndFeelPackage=$SILVERY_ID" "$KDEGLOBALS"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[KDE]\nLookAndFeelPackage=%s\n' '$SILVERY_ID' >> '$KDEGLOBALS'"
fi
echo "==> Silvery-Dark-Global-6 fijado como Tema Global por defecto."


# ==========================================
# 5.1A CONFIGURAR TEMA KVANTUM SILVERY
# ==========================================
echo "==> Configurando Kvantum con tema Silvery-Kvantum..."

KVANTUM_DIR="$USER_HOME/.local/share/Kvantum"
KVANTUM_THEME_DIR="$KVANTUM_DIR/Silvery"

sudo -u "$REAL_USER" mkdir -p "$KVANTUM_DIR"

# Descargar tema Silvery-Kvantum desde GitHub
if [ ! -d "$KVANTUM_THEME_DIR" ]; then
    echo "==> Descargando Silvery-Kvantum desde GitHub..."
    sudo -u "$REAL_USER" git clone https://github.com/L4ki/Silvery-Kvantum.git "$KVANTUM_THEME_DIR" || {
        echo "==> Aviso: No se pudo clonar Silvery-Kvantum desde GitHub."
    }
fi

# Configurar kvantumrc para usar Silvery como tema por defecto
KVANTUM_RC="$USER_HOME/.config/kvantum.kvconfig"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"

if [ -f "$KVANTUM_RC" ]; then
    if grep -q "^\[General\]" "$KVANTUM_RC"; then
        if grep -q "^theme=" "$KVANTUM_RC"; then
            sudo -u "$REAL_USER" sed -i 's|^theme=.*|theme=Silvery|' "$KVANTUM_RC"
        else
            sudo -u "$REAL_USER" sed -i '/^\[General\]/a theme=Silvery' "$KVANTUM_RC"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '[General]\ntheme=Silvery\n' >> '$KVANTUM_RC'"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '[General]\ntheme=Silvery\n' > '$KVANTUM_RC'"
fi

# Configurar kdeglobals para usar Kvantum como engine de estilo
if [ -f "$KDEGLOBALS" ] && grep -q "^\[General\]" "$KDEGLOBALS"; then
    if grep -q "^widgetStyle=" "$KDEGLOBALS"; then
        sudo -u "$REAL_USER" sed -i 's|^widgetStyle=.*|widgetStyle=kvantum|' "$KDEGLOBALS"
    else
        sudo -u "$REAL_USER" sed -i '/^\[General\]/a widgetStyle=kvantum' "$KDEGLOBALS"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[General]\nwidgetStyle=kvantum\n' >> '$KDEGLOBALS'"
fi

echo "==> Kvantum configurado con tema Silvery como engine por defecto."

# ==========================================
# 5.2 ICONOS SILVERY-DARK-ICONS POR DEFECTO
# ==========================================
echo "==> Configurando iconos Silvery-Dark-Icons por defecto..."

ICON_THEME_ID="Silvery-Dark-Icons"
SILVERY_ICONS_DIR=$(find /usr/share/icons "$USER_HOME/.local/share/icons" -maxdepth 1 -type d \( -iname "*silvery*dark*icon*" -o -iname "*silvery-dark-icons*" \) 2>/dev/null | head -n1 || true)

if [ -n "$SILVERY_ICONS_DIR" ]; then
    ICON_THEME_ID=$(basename "$SILVERY_ICONS_DIR")
    echo "==> Carpeta de iconos Silvery detectada: $SILVERY_ICONS_DIR"
else
    echo "==> Aviso: no se encontró Silvery-Dark-Icons instalado, se intentará instalar desde AUR..."
    yay -S silvery-dark-icons-git --noconfirm || echo "==> Aviso: no se pudo instalar silvery-dark-icons-git."
    SILVERY_ICONS_DIR=$(find /usr/share/icons "$USER_HOME/.local/share/icons" -maxdepth 1 -type d \( -iname "*silvery*dark*icon*" -o -iname "*silvery-dark-icons*" \) 2>/dev/null | head -n1 || true)
    if [ -n "$SILVERY_ICONS_DIR" ]; then
        ICON_THEME_ID=$(basename "$SILVERY_ICONS_DIR")
    fi
fi

KDEGLOBALS="$USER_HOME/.config/kdeglobals"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if [ -f "$KDEGLOBALS" ] && grep -q "^\[Icons\]" "$KDEGLOBALS"; then
    if grep -q "^Theme=" "$KDEGLOBALS"; then
        sudo -u "$REAL_USER" sed -i "s|^Theme=.*|Theme=$ICON_THEME_ID|" "$KDEGLOBALS"
    else
        sudo -u "$REAL_USER" sed -i "/^\[Icons\]/a Theme=$ICON_THEME_ID" "$KDEGLOBALS"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[Icons]\nTheme=%s\n' '$ICON_THEME_ID' >> '$KDEGLOBALS'"
fi
echo "==> Icon theme $ICON_THEME_ID fijado por defecto."


# ==========================================
# 5.3 TRANSPARENCIA POR DEFECTO EN KONSOLE
# ==========================================
echo "==> Configurando transparencia por defecto en Konsole..."
KONSOLE_DATA_DIR="$USER_HOME/.local/share/konsole"
sudo -u "$REAL_USER" mkdir -p "$KONSOLE_DATA_DIR"

BASE_COLORSCHEME="/usr/share/konsole/Breeze.colorscheme"
TRANSPARENT_SCHEME="$KONSOLE_DATA_DIR/BreezeTransparent.colorscheme"
if [ -f "$BASE_COLORSCHEME" ]; then
    sudo -u "$REAL_USER" cp "$BASE_COLORSCHEME" "$TRANSPARENT_SCHEME"
else
    echo "==> Aviso: no se encontró el color scheme base de Breeze, se crea uno mínimo."
    sudo -u "$REAL_USER" bash -c "printf '[Background]\nColor=35,38,41\n[Foreground]\nColor=252,252,252\n[General]\nDescription=BreezeTransparent\n' > '$TRANSPARENT_SCHEME'"
fi
if grep -q "^\[General\]" "$TRANSPARENT_SCHEME" && grep -q "^Opacity=" "$TRANSPARENT_SCHEME"; then
    sudo -u "$REAL_USER" sed -i "s|^Opacity=.*|Opacity=0.85|" "$TRANSPARENT_SCHEME"
elif grep -q "^\[General\]" "$TRANSPARENT_SCHEME"; then
    sudo -u "$REAL_USER" sed -i "/^\[General\]/a Opacity=0.85" "$TRANSPARENT_SCHEME"
else
    sudo -u "$REAL_USER" bash -c "printf '\n[General]\nOpacity=0.85\n' >> '$TRANSPARENT_SCHEME'"
fi

TRANSPARENT_PROFILE="$KONSOLE_DATA_DIR/Transparent.profile"
sudo -u "$REAL_USER" bash -c "printf '[Appearance]\nColorScheme=BreezeTransparent\n\n[General]\nName=Transparent\nParent=FALLBACK/\n' > '$TRANSPARENT_PROFILE'"

KONSOLERC="$USER_HOME/.config/konsolerc"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if [ -f "$KONSOLERC" ] && grep -q "^\[Desktop Entry\]" "$KONSOLERC"; then
    if grep -q "^DefaultProfile=" "$KONSOLERC"; then
        sudo -u "$REAL_USER" sed -i "s|^DefaultProfile=.*|DefaultProfile=Transparent.profile|" "$KONSOLERC"
    else
        sudo -u "$REAL_USER" sed -i "/^\[Desktop Entry\]/a DefaultProfile=Transparent.profile" "$KONSOLERC"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '[Desktop Entry]\nDefaultProfile=Transparent.profile\n' >> '$KONSOLERC'"
fi
echo "==> Konsole configurado con transparencia (Opacity=0.85) como perfil por defecto."

# Habilitar el efecto de escritorio Blur, para que la transparencia se vea bien
KWINRC="$USER_HOME/.config/kwinrc"
sudo -u "$REAL_USER" touch "$KWINRC"
if grep -q "^\[Plugins\]" "$KWINRC" 2>/dev/null; then
    if grep -q "^blurEnabled=" "$KWINRC"; then
        sudo -u "$REAL_USER" sed -i "s|^blurEnabled=.*|blurEnabled=true|" "$KWINRC"
    else
        sudo -u "$REAL_USER" sed -i "/^\[Plugins\]/a blurEnabled=true" "$KWINRC"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[Plugins]\nblurEnabled=true\n' >> '$KWINRC'"
fi


# ==========================================
# 6. CONFIGURACIÓN DE SYSTEM SERVICES, SDDM Y GRUB
# ==========================================
echo "==> Instalando y configurando tema SDDM Silvery-Dark-SDDM-6..."

SDDM_TMP=$(mktemp -d)
if git clone --depth 1 https://github.com/L4ki/Silvery-Plasma-Themes.git "$SDDM_TMP/silvery-themes"; then
    if [ -d "$SDDM_TMP/silvery-themes/Silvery-SDDM-6" ]; then
        sudo mkdir -p /usr/share/sddm/themes/silvery-dark
        sudo cp -r "$SDDM_TMP/silvery-themes/Silvery-SDDM-6/"* /usr/share/sddm/themes/silvery-dark/
        echo "==> Archivos de tema SDDM Silvery-Dark instalados en /usr/share/sddm/themes/silvery-dark."
    else
        echo "==> Aviso: No se encontró la carpeta Silvery-SDDM-6 dentro del repositorio."
    fi
else
    echo "==> Aviso: No se pudo clonar el repositorio Silvery-Plasma-Themes."
fi
rm -rf "$SDDM_TMP"

# Establecer Silvery-Dark como el tema activo en la configuración de SDDM
echo "==> Configurando /etc/sddm.conf.d/theme.conf.user..."
sudo mkdir -p /etc/sddm.conf.d
sudo bash -c 'cat > /etc/sddm.conf.d/theme.conf.user' << EOF
[Theme]
Current=silvery-dark
EOF

echo "==> Habilitando SDDM como Display Manager..."
for dm in entrance gdm lightdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
        echo "==> Deshabilitando $dm..."
        sudo systemctl disable "$dm"
    fi
done

sudo systemctl enable sddm


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
echo " Display manager configurado: SDDM (tema Silvery-Dark)"
echo " KDE Wallet: desactivado por defecto"
echo " Tema Global: Silvery-Dark-Global-6
 Kvantum: tema Silvery (para apps Qt)
 Icon theme: Silvery-Dark-Icons
 Konsole: transparencia por defecto (Opacity=0.85)
 Fondo de pantalla: incluido en Silvery-Dark-Global-6"
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
