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
yay -S stacer-bin sinergia-dd-burner iptvnator-bin yaru-colors-icon-theme yamis-icon-theme-git fetch-git --noconfirm
  
  
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

    # NOTA: el paquete "Tema Global" de Monochrome NO se instala vía install.sh
    # (solo está disponible como descarga interactiva en la KDE Store, sin URL fija
    # para automatizar de forma confiable). En su lugar, armamos el mismo resultado
    # visual aplicando manualmente cada pieza que el instalador SÍ deja en $HOME:
    # Plasma Theme, decoración de ventanas (Aurorae) y esquema de color.

    USER_UID=$(id -u "$REAL_USER")
    RUNTIME_DIR="/run/user/$USER_UID"
    if [ ! -d "$RUNTIME_DIR" ]; then
        RUNTIME_DIR=$(sudo -u "$REAL_USER" mktemp -d)
    fi

    # --- Plasma Theme (desktoptheme) ---
    PLASMATHEME_DIR=$(find "$USER_HOME/.local/share/plasma/desktoptheme" -maxdepth 1 -type d -iname "*onochrome*" 2>/dev/null | head -n1 || true)
    echo "==> Carpeta de Plasma Theme detectada: ${PLASMATHEME_DIR:-(ninguna)}"
    if [ -n "$PLASMATHEME_DIR" ]; then
        PLASMATHEME_ID=$(basename "$PLASMATHEME_DIR")
        if command -v plasma-apply-desktoptheme &>/dev/null; then
            sudo -u "$REAL_USER" env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$RUNTIME_DIR" \
                plasma-apply-desktoptheme "$PLASMATHEME_ID" || \
                echo "==> Aviso: plasma-apply-desktoptheme devolvió un error, se usará el respaldo directo."
        fi
        sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
        PLASMARC="$USER_HOME/.config/plasmarc"
        if [ -f "$PLASMARC" ] && grep -q "^\[Theme\]" "$PLASMARC"; then
            if grep -q "^name=" "$PLASMARC"; then
                sudo -u "$REAL_USER" sed -i "s|^name=.*|name=$PLASMATHEME_ID|" "$PLASMARC"
            else
                sudo -u "$REAL_USER" sed -i "/^\[Theme\]/a name=$PLASMATHEME_ID" "$PLASMARC"
            fi
        else
            sudo -u "$REAL_USER" bash -c "printf '\n[Theme]\nname=%s\n' '$PLASMATHEME_ID' >> '$PLASMARC'"
        fi
        echo "==> Plasma Theme $PLASMATHEME_ID fijado por defecto."
    else
        echo "==> Aviso: no se encontró el Plasma Theme de Monochrome instalado."
    fi

    # --- Decoración de ventanas (Aurorae) ---
    AURORAE_DIR=$(find "$USER_HOME/.local/share/aurorae/themes" -maxdepth 1 -type d -iname "*onochrome*" 2>/dev/null | head -n1 || true)
    echo "==> Carpeta de Aurorae detectada: ${AURORAE_DIR:-(ninguna)}"
    if [ -n "$AURORAE_DIR" ]; then
        AURORAE_ID=$(basename "$AURORAE_DIR")
        KWINRC="$USER_HOME/.config/kwinrc"
        sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
        sudo -u "$REAL_USER" touch "$KWINRC"
        if command -v kwriteconfig6 &>/dev/null; then
            KWRITECFG=kwriteconfig6
        else
            KWRITECFG=kwriteconfig5
        fi
        if command -v "$KWRITECFG" &>/dev/null; then
            sudo -u "$REAL_USER" "$KWRITECFG" --file "$KWINRC" --group "org.kde.kdecoration2" --key "library" "org.kde.kwin.aurorae"
            sudo -u "$REAL_USER" "$KWRITECFG" --file "$KWINRC" --group "org.kde.kdecoration2" --key "theme" "__aurorae__svg__$AURORAE_ID"
            echo "==> Decoración de ventanas Aurorae ($AURORAE_ID) fijada por defecto."
        else
            echo "==> Aviso: no se encontró kwriteconfig6/5, no se pudo fijar la decoración de ventanas."
        fi
    else
        echo "==> Aviso: no se encontró el tema Aurorae de Monochrome instalado."
    fi

    # --- Esquema de color ---
    COLORSCHEME_FILE=$(find "$USER_HOME/.local/share/color-schemes" -maxdepth 1 -type f -iname "*onochrome*.colors" 2>/dev/null | head -n1 || true)
    echo "==> Archivo de Color Scheme detectado: ${COLORSCHEME_FILE:-(ninguno)}"
    if [ -n "$COLORSCHEME_FILE" ]; then
        COLORSCHEME_ID=$(basename "$COLORSCHEME_FILE" .colors)
        if command -v plasma-apply-colorscheme &>/dev/null; then
            sudo -u "$REAL_USER" env QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$RUNTIME_DIR" \
                plasma-apply-colorscheme "$COLORSCHEME_ID" || \
                echo "==> Aviso: plasma-apply-colorscheme devolvió un error, se usará el respaldo directo."
        fi
        KDEGLOBALS="$USER_HOME/.config/kdeglobals"
        sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
        if [ -f "$KDEGLOBALS" ] && grep -q "^\[General\]" "$KDEGLOBALS"; then
            if grep -q "^ColorScheme=" "$KDEGLOBALS"; then
                sudo -u "$REAL_USER" sed -i "s|^ColorScheme=.*|ColorScheme=$COLORSCHEME_ID|" "$KDEGLOBALS"
            else
                sudo -u "$REAL_USER" sed -i "/^\[General\]/a ColorScheme=$COLORSCHEME_ID" "$KDEGLOBALS"
            fi
        else
            sudo -u "$REAL_USER" bash -c "printf '\n[General]\nColorScheme=%s\n' '$COLORSCHEME_ID' >> '$KDEGLOBALS'"
        fi
        echo "==> Color Scheme $COLORSCHEME_ID fijado por defecto."
    else
        echo "==> Aviso: no se encontró el Color Scheme de Monochrome instalado."
    fi
else
    echo "==> Aviso: no se pudo clonar el repositorio de Monochrome, se omite la instalación del tema."
fi

rm -rf "$THEME_BUILD_DIR"

# ==========================================
# 5.2 ICONOS YARU-GREY POR DEFECTO
# ==========================================
echo "==> Configurando iconos Yaru-Grey por defecto..."
ICON_DIR=$(find /usr/share/icons "$USER_HOME/.local/share/icons" -maxdepth 1 -type d -iname "*yaru*grey*" 2>/dev/null | head -n1 || true)
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
# 5.3 KVANTUM COMO ESTILO DE APLICACIÓN + TEMA MONOCHROME
# ==========================================
echo "==> Configurando Kvantum con el tema Monochrome..."
KVANTUM_THEME_DIR=$(find "$USER_HOME/.config/Kvantum" -maxdepth 1 -type d -iname "*onochrome*" 2>/dev/null | head -n1 || true)
echo "==> Carpeta de tema Kvantum detectada: ${KVANTUM_THEME_DIR:-(ninguna)}"

if [ -n "$KVANTUM_THEME_DIR" ]; then
    KVANTUM_THEME_ID=$(basename "$KVANTUM_THEME_DIR")
    KVANTUM_CONFIG="$USER_HOME/.config/Kvantum/kvantum.kvconfig"
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config/Kvantum"
    if [ -f "$KVANTUM_CONFIG" ] && grep -q "^\[General\]" "$KVANTUM_CONFIG"; then
        if grep -q "^theme=" "$KVANTUM_CONFIG"; then
            sudo -u "$REAL_USER" sed -i "s|^theme=.*|theme=$KVANTUM_THEME_ID|" "$KVANTUM_CONFIG"
        else
            sudo -u "$REAL_USER" sed -i "/^\[General\]/a theme=$KVANTUM_THEME_ID" "$KVANTUM_CONFIG"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '[General]\ntheme=%s\n' '$KVANTUM_THEME_ID' >> '$KVANTUM_CONFIG'"
    fi
    echo "==> Tema Kvantum $KVANTUM_THEME_ID fijado por defecto."
else
    echo "==> Aviso: no se encontró el tema Kvantum de Monochrome instalado."
fi

# Fijar Kvantum como estilo de aplicación (widget style) por defecto
KDEGLOBALS="$USER_HOME/.config/kdeglobals"
sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
if [ -f "$KDEGLOBALS" ] && grep -q "^\[KDE\]" "$KDEGLOBALS"; then
    if grep -q "^widgetStyle=" "$KDEGLOBALS"; then
        sudo -u "$REAL_USER" sed -i "s|^widgetStyle=.*|widgetStyle=kvantum|" "$KDEGLOBALS"
    else
        sudo -u "$REAL_USER" sed -i "/^\[KDE\]/a widgetStyle=kvantum" "$KDEGLOBALS"
    fi
else
    sudo -u "$REAL_USER" bash -c "printf '\n[KDE]\nwidgetStyle=kvantum\n' >> '$KDEGLOBALS'"
fi
echo "==> Kvantum fijado como estilo de aplicación por defecto."

# ==========================================
# 5.4 SKIN DE YAKUAKE MONOCHROME POR DEFECTO
# ==========================================
echo "==> Configurando skin de Yakuake Monochrome..."
YAKUAKE_SKIN_DIR=$(find "$USER_HOME/.local/share/yakuake/skins" -maxdepth 1 -type d -iname "*onochrome*" 2>/dev/null | head -n1 || true)
echo "==> Carpeta de skin de Yakuake detectada: ${YAKUAKE_SKIN_DIR:-(ninguna)}"

if [ -n "$YAKUAKE_SKIN_DIR" ]; then
    YAKUAKE_SKIN_ID=$(basename "$YAKUAKE_SKIN_DIR")
    YAKUAKERC="$USER_HOME/.config/yakuakerc"
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
    if [ -f "$YAKUAKERC" ] && grep -q "^\[Appearance\]" "$YAKUAKERC"; then
        if grep -q "^Skin=" "$YAKUAKERC"; then
            sudo -u "$REAL_USER" sed -i "s|^Skin=.*|Skin=$YAKUAKE_SKIN_ID|" "$YAKUAKERC"
        else
            sudo -u "$REAL_USER" sed -i "/^\[Appearance\]/a Skin=$YAKUAKE_SKIN_ID" "$YAKUAKERC"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '\n[Appearance]\nSkin=%s\n' '$YAKUAKE_SKIN_ID' >> '$YAKUAKERC'"
    fi
    echo "==> Skin de Yakuake $YAKUAKE_SKIN_ID fijado por defecto."
else
    echo "==> Aviso: no se encontró el skin de Yakuake de Monochrome instalado."
fi

# ==========================================
# 5.5 SUSTITUIR ICONOS POR YAMIS (Yet Another Monochrome Icon Set)
# ==========================================
echo "==> Sustituyendo iconos por YAMIS (Yet Another Monochrome Icon Set)..."
YAMIS_DIR=$(find /usr/share/icons "$USER_HOME/.local/share/icons" -maxdepth 1 -type d \( -iname "*yamis*" -o -iname "*yet*monochrome*" -o -iname "*another-monochrome*" \) 2>/dev/null | head -n1 || true)
echo "==> Carpeta de iconos YAMIS detectada: ${YAMIS_DIR:-(ninguna)}"

if [ -n "$YAMIS_DIR" ]; then
    YAMIS_ID=$(basename "$YAMIS_DIR")
    KDEGLOBALS="$USER_HOME/.config/kdeglobals"
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.config"
    if [ -f "$KDEGLOBALS" ] && grep -q "^\[Icons\]" "$KDEGLOBALS"; then
        if grep -q "^Theme=" "$KDEGLOBALS"; then
            sudo -u "$REAL_USER" sed -i "s|^Theme=.*|Theme=$YAMIS_ID|" "$KDEGLOBALS"
        else
            sudo -u "$REAL_USER" sed -i "/^\[Icons\]/a Theme=$YAMIS_ID" "$KDEGLOBALS"
        fi
    else
        sudo -u "$REAL_USER" bash -c "printf '\n[Icons]\nTheme=%s\n' '$YAMIS_ID' >> '$KDEGLOBALS'"
    fi
    echo "==> Icon theme $YAMIS_ID fijado por defecto, sustituyendo a Yaru-Grey."
else
    echo "==> Aviso: no se encontró el icon theme YAMIS instalado, se mantiene Yaru-Grey como icon theme por defecto."
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
echo " Tema Monochrome: Plasma Theme + Decoración de ventanas + Color Scheme + Kvantum + Yakuake
 Icon theme: YAMIS (Yet Another Monochrome Icon Set)
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
