#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO Y PACMAN (OPTIMIZACIONES SONICDE)
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
fi

echo "==> Aplicando ajustes recomendados en pacman.conf (ILoveCandy, ParallelDownloads)..."
if ! grep -q "ILoveCandy" /etc/pacman.conf; then
    sudo sed -i '/#Misc options/a ILoveCandy' /etc/pacman.conf
fi

if grep -q "#ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i 's/#ParallelDownloads/ParallelDownloads = 5/g' /etc/pacman.conf
elif ! grep -q "ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i '/#Misc options/a ParallelDownloads = 5' /etc/pacman.conf
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
# 3. CONFIGURACIÓN DEL REPOSITORIO CHAOTIC-AUR Y REPOSITORIO OFICIAL SONICDE
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

echo "==> Configurando el repositorio oficial de SonicDE..."
curl -O https://sonicde-arch.github.io/sonicde-archlinux.asc
sudo pacman-key --add sonicde-archlinux.asc
sudo pacman-key --finger 3B87898C73F11DF5
sudo pacman-key --lsign-key 3B87898C73F11DF5
rm -f sonicde-archlinux.asc

if ! grep -q "\[sonicde\]" /etc/pacman.conf; then
    echo "==> Agregando [sonicde] a pacman.conf..."
    sudo bash -c 'cat << EOF >> /etc/pacman.conf

[sonicde]
Server = https://sonicde-arch.github.io/\$arch
EOF'
fi

echo "==> Actualizando la base de datos de repositorios y del sistema..."
sudo pacman -Syyu --noconfirm


# ==========================================
# 4. INSTALACIÓN DE PAQUETES BASE, XLIBRE Y SONICDE-META
# ==========================================
echo "==> Instalando utilidades base del sistema..."
sudo pacman -S --needed ntfs-3g os-prober --noconfirm

echo "==> Instalando servidor de despliegue XLibre (stack X11)..."
sudo pacman -S --needed xlibre-server xlibre-xinit xlibre-apps xf86-input-libinput --noconfirm

echo "==> Instalando el paquete meta oficial de SonicDE (incluye SonicLogin)..."
sudo pacman -S sonicde-meta --noconfirm --needed


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

echo "==> Instalando paquetes adicionales desde AUR..."
yay -S --needed stacer-bin --noconfirm


# ==========================================
# 6. CONFIGURACIÓN ESPECÍFICA DE SONICDE Y ENTORNO DE USUARIO
# ==========================================
echo "==> Configurando variables de entorno e integración..."

REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo "~$REAL_USER")

sudo bash -c 'cat << EOF >> /etc/environment
XDG_CURRENT_DESKTOP=SonicDE
DESKTOP_SESSION=sonic
QT_QPA_PLATFORMTHEME=qt5ct
EOF'

cat << 'EOF' > "$USER_HOME/.xinitrc"
#!/bin/sh
userresources=$HOME/.Xresources
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

if [ -f $sysresources ]; then xrdb -merge $sysresources; fi
if [ -f $sysmodmap ]; then xmodmap $sysmodmap; fi
if [ -f "$userresources" ]; then xrdb -merge "$userresources"; fi
if [ -f "$usermodmap" ]; then xmodmap "$usermodmap"; fi

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
 for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
  [ -x "$f" ] && . "$f"
 done
 unset f
fi

exec sonic-session
EOF

chmod +x "$USER_HOME/.xinitrc"
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.xinitrc"


# ==========================================
# 7. GESTIÓN EXCLUSIVA DE SONICLOGIN Y GRUB
# ==========================================
echo "==> Deshabilitando otros gestores de inicio de sesión..."
sudo systemctl disable plasmalogin.service gdm.service sddm.service lightdm.service &>/dev/null
sudo systemctl stop plasmalogin.service gdm.service sddm.service lightdm.service &>/dev/null

echo "==> Habilitando el servicio SonicLogin..."
sudo systemctl enable soniclogin.service

echo "==> Habilitando os-prober en GRUB..."
if [ -f /etc/default/grub ]; then
    sudo sed -i "s/#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=\"false\"/" /etc/default/grub
fi

echo "==> Actualizando GRUB..."
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Limpiando archivos temporales..."
rm -rf ~/LinuxScripts

echo "==> Proceso finalizado con éxito. Reiniciando el sistema en 5 segundos..."
sleep 5
reboot
