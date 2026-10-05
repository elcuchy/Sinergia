#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO Y PACMAN
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
fi

# Agregar ILoveCandy y habilitar ParallelDownloads si no existen (CORREGIDO)
echo "==> Activando ILoveCandy y descargas paralelas en pacman.conf..."
if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    # Inserta ILoveCandy justo debajo de la cabecera [options]
    sudo sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi

if grep -q "^#ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf
elif ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i '/^\[options\]/a ParallelDownloads = 5' /etc/pacman.conf
fi


# ==========================================
# 1.1 CONFIGURACIÓN DEL REPOSITORIO MULTILIB
# ==========================================
echo "==> Verificando repositorio multilib..."

if grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "==> El repositorio multilib ya está habilitado."
elif grep -q "^#\[multilib\]" /etc/pacman.conf; then
    echo "==> Habilitando repositorio multilib (estaba comentado)..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
else
    echo "==> Agregando repositorio multilib (no existía en el archivo)..."
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF'
fi

sudo pacman -Sy


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

sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || \
sudo pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com:443
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


# Exit on error (si un comando falla, el script se detiene por seguridad)
set -e

# 1. Agregar el repositorio de Trinity Desktop (si no existe ya en pacman.conf)
if ! grep -q "\[trinity\]" /etc/pacman.conf; then
  echo "Añadiendo el repositorio [trinity] a /etc/pacman.conf..."
  sudo bash -c 'cat <<EOF >> /etc/pacman.conf

[trinity]
Server = https://mirror.ppa.trinitydesktop.org/trinity/archlinux/\$arch
EOF'
fi

# 2. Recibir y firmar la llave GPG
sudo pacman-key --recv-key D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B
sudo pacman-key --lsign-key D6D6FAA25E9A3E4ECD9FBDBEC93AF1698685AD8B

# 3. Actualizar las bases de datos de repositorios
sudo pacman -Sy --noconfirm

# 4. Instalar TDE y el resto de los paquetes
sudo pacman -S --noconfirm \
  tde-tdebase \
  tde-i18n-es \
  amd-ucode \
  intel-ucode \
  okular \
  vlc \
  ark \
  unrar \
  p7zip \
  chromium \
  firefox \
  firefox-i18n-es-ar \
  libreoffice-fresh-es \
  hunspell-es_uy \
  telegram-desktop \
  zsh \
  zsh-completions \
  fastfetch \
  ntfs-3g \
  archlinux-tweak-tool-gtk4 \
  terminology \
  vlc-plugins-all \
  hardinfo2 \
  mpv \
  btop \
  gparted \
  nano \
  ulauncher \
  audacious \
  octopi \
  tde-dolphin \
  tde-kmplayer \
  os-prober

# ==========================================
# . INSTALACIÓN DE YAY Y PAQUETES AUR
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
yay -S stacer-bin --noconfirm

# 5. Configurar GRUB para detectar otros sistemas operativos
sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 6. Habilitar el gestor de inicio de TDE
sudo systemctl enable tdm.service

# ==========================================
# LIMPIEZA Y REINICIO
# ==========================================
# Nota: se usa TARGET_HOME (calculado en la sección 6 a partir del usuario
# real) y no $HOME, que con sudo puede apuntar a /root.

echo "==> Eliminando dependencias huérfanas (p. ej. dependencias de compilación de yay)..."
ORPHANS=$(pacman -Qdtq 2>/dev/null || true)
if [ -n "$ORPHANS" ]; then
    # shellcheck disable=SC2086
    sudo pacman -Rns --noconfirm $ORPHANS || echo "==> Aviso: no se pudieron quitar algunos huérfanos, se continúa."
else
    echo "==> No hay paquetes huérfanos."
fi

echo "==> Limpiando caché de pacman (se conservan los paquetes instalados)..."
sudo pacman -Sc --noconfirm >/dev/null || true

echo "==> Limpiando caché de compilación de yay..."
rm -rf "$TARGET_HOME/.cache/yay" 2>/dev/null || true

SCRIPT_REPO_DIR="$TARGET_HOME/LinuxScripts"
if [ -d "$SCRIPT_REPO_DIR" ]; then
    echo "==> Limpiando carpeta del script ($SCRIPT_REPO_DIR)..."
    # Salimos de la carpeta antes de borrarla, por si el script se ejecuta desde ahí
    cd "$TARGET_HOME"
    rm -rf "$SCRIPT_REPO_DIR"
fi

# Resumen final (coincide con lo que realmente instala este script)
cat << EOF
======================================================
 Instalación y configuración completadas con éxito.
 Display manager:       TDM (tema Minimalista)
 Entorno de escritorio: Trinity Desktop (TDE)
 Gestores de paquetes:  pacman, yay, octopi
 Repositorios activos:  multilib + kiro (nemesis_repo) + chaotic-aur + trinity

 SSSS   III   N   N  EEEEE  RRRR    GGG    III    AAA
S        I    NN  N  E      R   R  G   G    I    A   A
S        I    N N N  E      R   R  G        I    A   A
 SSS     I    N N N  EEEE   RRRR   G GGG    I    AAAAA
    S    I    N  NN  E      R R    G   G    I    A   A
    S    I    N   N  E      R  R   G   G    I    A   A
SSSS    III   N   N  EEEEE  R   R   GGG    III   A   A
======================================================
            COMUNIDAD    LINUXERA
======================================================
EOF

# Si no hay terminal interactiva (stdin redirigido), no reiniciamos solos
if [ -t 0 ]; then
    read -r -t 15 -p "¿Reiniciar el sistema ahora? (S/n, reinicia solo en 15s): " respuesta || respuesta="s"
    echo
else
    respuesta="n"
fi

case "${respuesta,,}" in
    s|si|sí|"")
        echo "==> Sincronizando discos y reiniciando..."
        sync
        sudo systemctl reboot
        ;;
    *)
        echo "==> Reinicio cancelado. Recordá reiniciar manualmente para aplicar los cambios."
        ;;
esac
