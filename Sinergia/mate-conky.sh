#!/bin/bash

# ==========================================
# 1. CONFIGURACIÓN DE RESPALDO Y PACMAN
# ==========================================
if [ ! -f /etc/pacman.conf.bak_repos ]; then
    echo "==> Creando respaldo de /etc/pacman.conf..."
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak_repos
fi

# Si una corrida anterior se cortó a mitad de camino, pacman.conf puede haber
# quedado con un Include apuntando a un mirrorlist que nunca se llegó a crear.
# Esto rompe pacman por completo, asi que lo detectamos y corregimos antes de seguir.
echo "==> Verificando integridad de pacman.conf..."
if grep -q "^Include = /etc/pacman.d/kiro-mirrorlist" /etc/pacman.conf && [ ! -f /etc/pacman.d/kiro-mirrorlist ]; then
    echo "   - kiro-mirrorlist roto (no existe el archivo), revirtiendo a Server= temporal..."
    sudo sed -i 's|^Include = /etc/pacman.d/kiro-mirrorlist|Server = https://erikdubois.github.io/$repo/$arch|' /etc/pacman.conf
fi
if grep -q "^Include = /etc/pacman.d/chaotic-mirrorlist" /etc/pacman.conf && [ ! -f /etc/pacman.d/chaotic-mirrorlist ]; then
    echo "   - chaotic-mirrorlist roto (no existe el archivo), eliminando la sección para recrearla..."
    sudo sed -i '/^\[chaotic-aur\]$/,/^Include = \/etc\/pacman.d\/chaotic-mirrorlist$/d' /etc/pacman.conf
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

if [ ! -f /etc/pacman.d/kiro-mirrorlist ]; then
    echo "==> ERROR: kiro-mirrorlist no se instaló (probable falla de red temporal)."
    echo "    No se va a tocar pacman.conf para evitar dejarlo roto. Corré el script de nuevo."
    exit 1
fi

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

if [ ! -f /etc/pacman.d/chaotic-mirrorlist ]; then
    echo "==> ERROR: chaotic-mirrorlist no se instaló (probable falla de red temporal)."
    echo "    No se va a tocar pacman.conf para evitar dejarlo roto. Corré el script de nuevo."
    exit 1
fi

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


# 4. Instalar xfce y el resto de los paquetes
sudo pacman -S --noconfirm \
  xorg-server \
  xorg-apps \
  mate \
  mate-extra \
  mate-tweak \
  mate-themes \
  mate-icon-theme-faenza \
  brisk-menu \
  mate-applet-dock \
  plank \
  synapse \
  vala-panel-appmenu-mate \
  mate-netbook \
  python-gobject \
  dbus \
  lightdm \
  lightdm-gtk-greeter \
  lightdm-slick-greeter \
  pipewire-pulse \
  wireplumber \
  pavucontrol \
  network-manager-applet \
  amd-ucode \
  intel-ucode \
  vlc \
  unrar \
  p7zip \
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
  audacious \
  shelly \
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
  transmission-gtk \
  conky \
  lm_sensors \
  unzip \
  ufw \
  pacman-contrib \
  ttf-monofur \
  gnome-boxes \
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
yay -S stacer-bin mate-menu sinergia-dd-burner iptvnator-bin yaru-colors-icon-theme fetch-git --noconfirm

# ==========================================
# 4.1 PERFILES DE PANEL PARA MATE-TWEAK
#     (Cupertino, Redmond, Mutiny, Netbook, etc.)
# ==========================================
echo "==> Instalando layouts de panel adicionales para mate-tweak..."
sudo mkdir -p /usr/share/mate-panel/layouts
LAYOUTS_BASE="https://raw.githubusercontent.com/ubuntu-mate/ubuntu-mate-settings/master/usr/share/mate-panel/layouts"
for f in eleven.layout eleven.dock redmond.layout mutiny.layout mutiny.dock \
         netbook.layout contemporary.layout familiar.layout pantheon.layout \
         pantheon.dock ubuntu-mate.layout; do
    if sudo curl -fsSL "$LAYOUTS_BASE/$f" -o "/usr/share/mate-panel/layouts/$f"; then
        echo "   - $f OK"
    else
        echo "   - $f no se pudo descargar, se omite"
        sudo rm -f "/usr/share/mate-panel/layouts/$f"
    fi
done
# Nota: dentro de mate-tweak, Cupertino aparece internamente como "eleven".

echo "==> Generando layout propio para el perfil Manjaro..."
sudo tee /usr/share/mate-panel/layouts/manjaro.layout > /dev/null << 'LAYOUTEOF'
[Toplevel bottom]
expand=true
orientation=bottom
size=28

[Object briskmenu]
object-type=applet
applet-iid=BriskMenuFactory::BriskMenu
toplevel-id=bottom
position=0
locked=true

[Object showdesktopapplet]
locked=true
position=10
toplevel-id=bottom
applet-iid=WnckletFactory::ShowDesktopApplet
object-type=applet

[Object window-list]
object-type=applet
applet-iid=WnckletFactory::WindowListApplet
toplevel-id=bottom
position=20
locked=true

[Object workspace-switcher]
object-type=applet
applet-iid=WnckletFactory::WorkspaceSwitcherApplet
toplevel-id=bottom
position=10
relative-to-edge=end
locked=true

[Object drivemountapplet]
object-type=applet
applet-iid=DriveMountAppletFactory::DriveMountApplet
toplevel-id=bottom
position=30
relative-to-edge=end
locked=true

[Object notification-area]
object-type=applet
applet-iid=NotificationAreaAppletFactory::NotificationArea
toplevel-id=bottom
position=20
relative-to-edge=end
locked=true

[Object indicatorappletcomplete]
object-type=applet
applet-iid=IndicatorAppletCompleteFactory::IndicatorAppletComplete
toplevel-id=bottom
position=0
relative-to-edge=end
locked=true
LAYOUTEOF

echo "==> Personalizando layout del perfil Pantheon (menu izq. / synapse+red+reloj der.)..."
sudo tee /usr/share/mate-panel/layouts/pantheon.layout > /dev/null << 'LAYOUTEOF'
[Toplevel top]
expand=true
orientation=top
size=28

[Object briskmenu]
object-type=applet
applet-iid=BriskMenuFactory::BriskMenu
toplevel-id=top
position=0
locked=true

[Object notification-area]
object-type=applet
applet-iid=NotificationAreaAppletFactory::NotificationArea
toplevel-id=top
position=20
panel-right-stick=true
locked=true

[Object clock]
object-type=applet
applet-iid=ClockAppletFactory::ClockApplet
toplevel-id=top
position=10
panel-right-stick=true
locked=true
LAYOUTEOF

echo "==> Creando script central para cambiar de layout (panel + dock)..."
sudo tee /usr/local/bin/set-panel-layout > /dev/null << 'HELPEREOF'
#!/bin/bash
# Uso: set-panel-layout <nombre-de-layout>
layout="$1"
[ -z "$layout" ] && { echo "Uso: set-panel-layout <layout>"; exit 1; }

killall mate-panel 2>/dev/null
dconf reset -f /org/mate/panel/
mate-panel --reset --layout "$layout"

# mate-panel a veces duplica las entradas de object-id-list al resetear,
# y algunos applets (como el menu) se registran tarde via D-Bus.
# Reintenta la deduplicacion varias veces para agarrar tambien esos casos.
for i in 1 2 3; do
    sleep 1
    ids=$(dconf read /org/mate/panel/general/object-id-list 2>/dev/null)
    if [ -n "$ids" ]; then
        dedup=$(python3 -c "
import ast
lst = ast.literal_eval('''$ids''')
seen = []
for x in lst:
    if x not in seen:
        seen.append(x)
print(seen)
" 2>/dev/null)
        [ -n "$dedup" ] && dconf write /org/mate/panel/general/object-id-list "$dedup"
    fi
done

dockfile="/usr/share/mate-panel/layouts/${layout}.dock"
if [ -s "$dockfile" ]; then
    dockapp=$(tr -d '[:space:]' < "$dockfile")
    dconf write /org/mate/desktop/session/required-components/dock "'${dockapp}'"
    killall "$dockapp" 2>/dev/null
    nohup "$dockapp" >/dev/null 2>&1 &
else
    dconf write /org/mate/desktop/session/required-components/dock "''"
    killall plank 2>/dev/null
fi
HELPEREOF
sudo chmod +x /usr/local/bin/set-panel-layout

# ==========================================
# 4.2 APARIENCIA Y VALORES POR DEFECTO
#     (tema, iconos, fondo, perfil de panel, synapse)
# ==========================================
echo "==> Generando tema de íconos con el logo de Arch para el menú..."
sudo mkdir -p /usr/share/icons/Mint-Y-Yaru-Arch/scalable/places
sudo tee /usr/share/icons/Mint-Y-Yaru-Arch/index.theme > /dev/null << 'THEMEEOF'
[Icon Theme]
Name=Mint-Y-Yaru-Arch
Comment=Mint-Y-Yaru con el logo de Arch Linux en el menu
Inherits=Mint-Y-Yaru
Directories=scalable/places

[scalable/places]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
Context=Places
THEMEEOF
sudo cp /usr/share/pixmaps/archlinux-logo.svg /usr/share/icons/Mint-Y-Yaru-Arch/scalable/places/start-here.svg

echo "==> Configurando lanzadores por defecto de Plank (evita que se auto-siembre roto)..."
# /etc/skel NO sirve aca: la cuenta del usuario ya existe (se crea durante la
# instalacion base de Arch, antes de este script), asi que hay que aplicar el
# fix directo sobre su carpeta real, igual que a cualquier cuenta ya creada.
killall plank 2>/dev/null || true
chattr -i "$HOME/.config/plank/dock1/launchers/" 2>/dev/null || true
rm -rf "$HOME/.config/plank/dock1/launchers"
mkdir -p "$HOME/.config/plank/dock1/launchers"
tee "$HOME/.config/plank/dock1/launchers/matecc.dockitem" > /dev/null << 'EOF'
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/matecc.desktop
EOF
chattr +i "$HOME/.config/plank/dock1/launchers/" 2>/dev/null || echo "   - chattr no soportado en este filesystem, se omite la protección"

echo "==> Instalando widget de sistema Conky..."
# Nota: esto se instala en la carpeta personal del usuario que corre el script,
# igual que el fix de Plank de arriba - no aplica retroactivamente a otras cuentas.
rm -rf "$HOME/.conky"
mkdir -p "$HOME/.conky"

# Deteccion de hardware real de esta maquina (disco raiz, interfaz de red activa).
CONKY_ROOT_PART=$(findmnt -no SOURCE / 2>/dev/null)
CONKY_ROOT_DEV=$(lsblk -no pkname "$CONKY_ROOT_PART" 2>/dev/null | head -1)
[ -z "$CONKY_ROOT_DEV" ] && CONKY_ROOT_DEV=$(basename "$CONKY_ROOT_PART" 2>/dev/null)
[ -z "$CONKY_ROOT_DEV" ] && CONKY_ROOT_DEV="sda"

CONKY_IFACE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
[ -z "$CONKY_IFACE" ] && CONKY_IFACE=$(ip -br link show up 2>/dev/null | awk '$1!="lo"{print $1; exit}')
[ -z "$CONKY_IFACE" ] && CONKY_IFACE="eth0"

CONKY_FSTYPE=$(findmnt -no FSTYPE / 2>/dev/null | tr '[:lower:]' '[:upper:]')
[ -z "$CONKY_FSTYPE" ] && CONKY_FSTYPE="ROOT"

tee "$HOME/.conky/conkyrc" > /dev/null << 'CONKYEOF'
-- vim: ts=4 sw=4 noet ai cindent syntax=lua
conky.config = {
    alignment = 'top_right',
    background = true,
    border_width = 0,
    cpu_avg_samples = 2,
	default_color = '#C0C0C0',
    default_outline_color = '#C0C0C0',
    default_shade_color = '#C0C0C0',
    draw_borders = true,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    use_xft = true,
    font = 'fixed:size=10:bold',
    gap_x = 0,
    gap_y = 28,
    minimum_height = 5,
	minimum_width = 5,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_stderr = false,
    extra_newline = false,
    own_window = true,
	own_window_transparent = true,
	own_window_hints = 'undecorated,skip_taskbar,below,skip_pager,sticky',
    stippled_borders = 0,
	temperature_unit = 'celsius';
    update_interval = 1,
    uppercase = false,
    use_spacer = 'none',
    show_graph_scale = false,
    show_graph_range = false,
	double_buffer = true,
	own_window_type = 'normal',
	own_window_class = 'conky',
	own_window_title = 'conky',
	maximum_width = 200,
}
conky.text = [[
 
${color #C0C0C0}OS: ${color #FFFFFF}__OS_INFO__
${color #C0C0C0}Kernel: ${color #FFFFFF}$kernel
${color #C0C0C0}System: ${color #FFFFFF}${exec cat /sys/devices/virtual/dmi/id/product_name}
${color #C0C0C0}Uptime: ${color #FFFFFF}$uptime

${color #C0C0C0}COMMAND           ${color #C0C0C0}MEM%  CPU%
${color #FFFFFF}${top name 1}${top mem 1}${top cpu 1}
${color #FFFFFF}${top name 2}${top mem 2}${top cpu 2}
${color #FFFFFF}${top name 3}${top mem 3}${top cpu 3}

${color #C0C0C0}Processes: ${color #FFFFFF}$processes${color #C0C0C0}${alignr}Running: ${color #FFFFFF}$running_processes

${color #C0C0C0}CPU0: ${color #FFFFFF}${cpu cpu0}% $alignr ${exec awk '/cpu MHz/{i++}i==1{printf "%.f",$4; exit}' /proc/cpuinfo}MHz    ${hwmon 0 temp 2}°C
${cpubar cpu0 12, 200}
${color #C0C0C0}${cpugraph cpu0 12, 200}
__CPU1_BLOCK__
${color #C0C0C0}MEM%: ${color #FFFFFF}$memperc%${alignr}$mem / $memmax
${membar 12, 200}
${color #C0C0C0}${memgraph 12, 200}
${color #C0C0C0}SWAP: ${color #FFFFFF}$swapperc%${alignr}$swap / $swapmax
${color #FFFFFF}${swapbar 12, 200}
${color #C0C0C0}${diskiograph __ROOTDEV__ 12, 200}

${color #C0C0C0}__FSTYPE__: ${color #FFFFFF}${fs_used_perc /}%  ${fs_used /} /${alignr}${fs_size /}
${fs_bar 12, 200 /}
${color #C0C0C0}${diskiograph __ROOTDEV__ 12, 200}

${color #C0C0C0}WLAN: ${color #FFFFFF}${wireless_link_qual_perc __IFACE__}% ${alignr}${color #C0C0C0}${color #FFFFFF}${upspeed __IFACE__} / ${downspeed __IFACE__}
${color #FFFFFF}${wireless_link_bar 12, 200 __IFACE__}
${color #C0C0C0}${upspeedgraph __IFACE__ 12, 97} ${alignr}${downspeedgraph __IFACE__ 12,96}

${color #C0C0C0}WLAN: ${color #FFFFFF}${addr __IFACE__}${font}
${color #C0C0C0}ESSID: ${color #FFFFFF}${wireless_essid __IFACE__}${font}
${color #C0C0C0}ROUTE: ${color #FFFFFF}${execi 60 ip route | sed -n "1 p" | cut -c1-45}${font}
${color #C0C0C0}DNS: ${color #FFFFFF}${execi 60 cat /etc/resolv.conf | cut -c12-}${font}
${color #C0C0C0}WAN: ${color #FFFFFF}${execi 300 curl -s https://ifconfig.me}${font}

${color #C0C0C0}Outgoing: ${color #FFFFFF}${tcp_portmon 32767 
65535 count}${alignr}${color #C0C0C0}Incoming: ${color #FFFFFF}${tcp_portmon 1 32768 count}

${color #C0C0C0}HOST: ${alignr} PORT:$color
${color #FFFFFF}${tcp_portmon 32768 65535 rip 0} ${alignr} ${tcp_portmon 32768 65535 lservice 0}
${color #FFFFFF}${tcp_portmon 32768 65535 rip 1} ${alignr} ${tcp_portmon 32768 65535 lservice 1}
${color #FFFFFF}${tcp_portmon 32768 65535 rip 2} ${alignr} ${tcp_portmon 32768 65535 lservice 2}

${color #FFFFFF}${tcp_portmon 1 32767 rip 0} ${alignr} ${tcp_portmon 1 32767 lservice 0}
]]
CONKYEOF

# Sustituir los marcadores por los valores reales detectados y adaptar a Arch
# (reemplazo de texto literal en Python para no pelear con sed y los $ de Conky).
python3 << PYEOF
import os
path = os.path.expanduser("~/.conky/conkyrc")
with open(path, "r") as f:
    content = f.read()

ncores = os.cpu_count() or 1
cpu_extra_blocks = []
for n in range(1, ncores):
    cpu_extra_blocks.append(
        "\${color #C0C0C0}CPU" + str(n) + ": \${color #FFFFFF}\${cpu cpu" + str(n) + "}%\n"
        + "\${cpubar cpu" + str(n) + " 12, 200}\n"
        + "\${color #C0C0C0}\${cpugraph cpu" + str(n) + " 12, 200}"
    )
cpu1_block = "\n".join(cpu_extra_blocks)

replacements = {
    "__OS_INFO__": '''\${execi 999999 awk -F'"' '/PRETTY_NAME/{print \$2}' /etc/os-release}''',
    "__CPU1_BLOCK__": cpu1_block,
    "__ROOTDEV__": "$CONKY_ROOT_DEV",
    "__IFACE__": "$CONKY_IFACE",
    "__FSTYPE__": "$CONKY_FSTYPE",
}
for old, new in replacements.items():
    content = content.replace(old, new)

with open(path, "w") as f:
    f.write(content)
PYEOF

tee "$HOME/.conky/start-conky.sh" > /dev/null << 'STARTEOF'
#!/usr/bin/env bash
sleep 5
killall conky 2>/dev/null || true
conky -c "$HOME/.conky/conkyrc"
STARTEOF
chmod +x "$HOME/.conky/start-conky.sh"

mkdir -p "$HOME/.config/autostart"
rm -f "$HOME/.config/autostart/systemmon-conky.desktop"
tee "$HOME/.config/autostart/conky.desktop" > /dev/null << EOF
[Desktop Entry]
Type=Application
Name=Conky
Comment=Widget de monitoreo de sistema en el escritorio
Exec=$HOME/.conky/start-conky.sh
Icon=utilities-system-monitor
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo "==> Configurando transparencia en MATE Terminal..."
dconf write /org/mate/terminal/profiles/default/background-type "'transparent'"
dconf write /org/mate/terminal/profiles/default/background-darkness 0.75
gsettings set org.mate.Marco.general compositing-manager true

echo "==> Evitando menú duplicado de LibreOffice con el menú global (vala-panel-appmenu)..."
if ! grep -q "^SAL_USE_VCLPLUGIN=" /etc/environment 2>/dev/null; then
    echo "SAL_USE_VCLPLUGIN=gen" | sudo tee -a /etc/environment > /dev/null
fi

echo "==> Descargando fondo de pantalla por defecto..."
sudo mkdir -p /usr/share/backgrounds
sudo curl -fsSL "https://raw.githubusercontent.com/f4dzN/archlinux-wallpapers/refs/heads/main/wallpapers/11.png" \
    -o /usr/share/backgrounds/archlinux-wallpaper.png

echo "==> Configurando valores por defecto de MATE (dconf)..."
sudo mkdir -p /etc/dconf/profile
sudo tee /etc/dconf/profile/user > /dev/null << 'PROFILEEOF'
user-db:user
system-db:local
PROFILEEOF

sudo mkdir -p /etc/dconf/db/local.d
sudo tee /etc/dconf/db/local.d/01-mate-defaults > /dev/null << 'DCONFEOF'
[org/mate/desktop/background]
picture-filename='/usr/share/backgrounds/archlinux-wallpaper.png'
picture-options='zoom'

[org/mate/desktop/interface]
gtk-theme='BlackMATE'
icon-theme='Mint-Y-Yaru-Arch'

[org/mate/marco/general]
theme='BlackMATE'
compositing-manager=true

[org/mate/panel/general]
default-layout='pantheon'

[org/mate/desktop/session/required-components]
dock='plank'

[org/mate/terminal/profiles/default]
background-type='transparent'
background-darkness=0.75
DCONFEOF
sudo dconf update

echo "==> Configurando lightdm-slick-greeter como pantalla de inicio de sesión..."
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo tee /etc/lightdm/lightdm.conf.d/90-greeter.conf > /dev/null << 'GREETEREOF'
[Seat:*]
greeter-session=lightdm-slick-greeter
GREETEREOF

sudo mkdir -p /etc/lightdm
sudo tee /etc/lightdm/slick-greeter.conf > /dev/null << 'SLICKEOF'
[Greeter]
background=/usr/share/backgrounds/archlinux-wallpaper.png
theme-name=BlackMATE
icon-theme-name=Mint-Y-Yaru-Arch
SLICKEOF

echo "==> Configurando Synapse para iniciar junto con la sesión..."
if [ -f /usr/share/applications/synapse.desktop ]; then
    sudo mkdir -p /etc/xdg/autostart
    sudo cp /usr/share/applications/synapse.desktop /etc/xdg/autostart/synapse.desktop
    sudo sed -i '/^X-GNOME-Autostart-enabled/d' /etc/xdg/autostart/synapse.desktop
    echo "X-GNOME-Autostart-enabled=true" | sudo tee -a /etc/xdg/autostart/synapse.desktop > /dev/null
else
    echo "   - No se encontró synapse.desktop, se omite el autostart."
fi

echo "==> Configurando autostart del dock (Plank) según el perfil de panel..."
sudo tee /usr/local/bin/dock-autostart > /dev/null << 'DOCKEOF'
#!/bin/bash
dock=$(dconf read /org/mate/desktop/session/required-components/dock 2>/dev/null | tr -d "'")
[ -n "$dock" ] && exec "$dock"
DOCKEOF
sudo chmod +x /usr/local/bin/dock-autostart

sudo mkdir -p /etc/xdg/autostart
sudo tee /etc/xdg/autostart/dock-autostart.desktop > /dev/null << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=Dock Autostart
Comment=Inicia el dock (ej. Plank) segun el perfil de panel activo
Exec=/usr/local/bin/dock-autostart
Icon=plank
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=2
NoDisplay=true
DESKEOF

echo "==> Creando lanzadores de perfiles de panel (evitan el filtro de mate-tweak)..."
sudo mkdir -p /usr/share/applications

declare -A PANEL_LAYOUTS=(
    ["eleven"]="Perfil de Panel: Cupertino"
    ["redmond"]="Perfil de Panel: Redmond"
    ["mutiny"]="Perfil de Panel: Mutiny"
    ["netbook"]="Perfil de Panel: Netbook"
    ["contemporary"]="Perfil de Panel: Contemporary"
    ["pantheon"]="Perfil de Panel: Pantheon"
    ["manjaro"]="Perfil de Panel: Manjaro"
)

for layout in "${!PANEL_LAYOUTS[@]}"; do
    name="${PANEL_LAYOUTS[$layout]}"
    sudo tee "/usr/share/applications/panel-layout-${layout}.desktop" > /dev/null << EOF
[Desktop Entry]
Type=Application
Name=${name}
Comment=Cambia el layout del panel de MATE a ${layout}
Exec=/usr/local/bin/set-panel-layout ${layout}
Icon=mate-panel
Terminal=false
Categories=Settings;DesktopSettings;
NoDisplay=false
EOF
done

# 5. Configurar GRUB para detectar otros sistemas operativos
sudo sed -i.bak 's/#\?\(GRUB_DISABLE_OS_PROBER=\).*/\1false/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# 6. Habilitar el gestor de inicio
sudo systemctl enable lightdm

echo "==> Habilitando firewall (ufw)..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable
sudo systemctl enable ufw

# ==========================================
# 7. LIMPIEZA Y RESUMEN FINAL
# ==========================================
rm -rf "$HOME/LinuxScripts"

echo "======================================================"
echo " Instalación y configuración completadas con éxito."
echo " Display manager configurado: LightDM (GTK Greeter)"
echo " Entorno de escritorio: Mate"
echo " Repositorios habilitados: multilib, chaotic-aur"
echo " Gestor de paquetes AUR: yay"
echo " GRUB: os-prober habilitado (detección de otros SO)"
echo " Respaldo de pacman.conf: /etc/pacman.conf.bak_repos"
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
