#!/bin/bash

p34='\033[1;1;34m'
p00='\033[0m'
setfont lat9u-10
onroot='arch-chroot /mnt' #root

echo -e "$p34                   -'\n                  .o+'\n                 'ooo:\n                '+oooo:\n               '+oooooo:\n               -+oooooo+:\n             '::-:++oooo+:\n            ':++++:+++++++:\n           ':++++++++++++++:\n          ':+++ooooooooooooo:'\n         .:oooooooo++oooooooo+'\n        .oooooooo-'''':ooooooo+'\n       -oooooooo.      :oooooooo.\n      :oooooooo:        oooooo+++.\n     :ooooooooo:        +ooooooo:-\n   ':ooooooo+::-        -::+oooooo+-\n  '+ooo+:-'                 '.-:+ooo:\n '++:.                           '-:+:\n .'                                 '.$p00"
echo -e "$p34\nproyecto dArch-updte$p00"

timedatectl; timedatectl set-ntp 1

fdisk -l; echo -e "$p34:: particion en \"nvme0n1?\"$p00"; read hdd

if [ "$hdd" = "nvme0n1" ]; then
    hdd="${hdd}p"
fi

if [ -b "$hdd" ] && sfdisk -d "$hdd" &> /dev/null; then
    umount -R /mnt; sfdisk --delete "/dev/$hdd"
fi

echo -e "m\ng\nn\n1\n\n+${EFI_boot:=2048}M\nn\n2\n\n\nt\n1\n1\nw" | fdisk /dev/$hdd

mkfs.fat -F 32 -I /dev/"${hdd}1"; mkfs.btrfs -f -n 32k /dev/"${hdd}2"

mount /dev/"${hdd}2" /mnt; btrfs subvolume create /mnt/@; btrfs subvolume create /mnt/@home; btrfs subvolume create /mnt/@dArch; umount /mnt

mount -o compress=zstd:3,subvol=@ /dev/"${hdd}2" /mnt

mkdir -p /mnt/home; mount -o compress=zstd:3,subvol=@home /dev/"${hdd}2" /mnt/home
mkdir -p /mnt/dArch; mount -o compress=zstd:3,subvol=@dArch /dev/"${hdd}2" /mnt/dArch
mkdir -p /mnt/boot; mount /dev/"${hdd}1" /mnt/boot

pacstrap /mnt base base-devel linux btrfs-progs nano linux-firmware  --noconfirm --needed

genfstab -U /mnt >> /mnt/etc/fstab
sed -i '/btrfs/s/relatime/noatime,commit=60/' /mnt/etc/fstab

timezone=$(tzselect)
$onroot ln -sf /usr/share/zoneinfo/$timezone /etc/localtime; $onroot hwclock -w

$onroot sed -i '/#es_UY.UTF-8 UTF-8/s/#es_UY.UTF-8 UTF-8/es_UY.UTF-8 UTF-8/' /etc/locale.gen
$onroot locale-gen
$onroot echo -e 'LANG=es_UY.UTF-8' > /mnt/etc/locale.conf

$onroot echo -e 'KEYMAP=es\nFONT=lat9u-10\nFONT_MAP=8859-2' > /mnt/etc/vconsole.conf

echo -e "$p34:: nombre pc \"pchome1\"$p00"; read -t 40 -p "" nombre_pc
nombre_pc=${nombre_pc:=pchome1}
$onroot echo -e $nombre_pc > /mnt/etc/hostname

$onroot pacman -S networkmanager --noconfirm --needed; $onroot systemctl enable NetworkManager.service

echo -e "$p34:: root pw. \"root\"$p00"; read -t 40 -p "" root_pw
root_pw=${root_pw:=root}
$onroot echo -e "$root_pw\n$root_pw" | $onroot passwd

$onroot pacman -S grub efibootmgr --noconfirm --needed
$onroot grub-install --target=x86_64-efi --efi-directory=/boot; $onroot grub-mkconfig -o /boot/grub/grub.cfg

echo -e "$p34:: nombre (no root) \"pchome\"$p00"; read -t 40 -p "" nombre
nombre=${nombre:=pchome}
$onroot useradd -m -G wheel $nombre
echo -e "$p34:: pw. (no root) \"pchome\"$p00"; read -t 40 -p "" pw
pw=${pw:=pchome}
echo -e "$pw\n$pw" | $onroot passwd $nombre

$onroot sed -i '/# %wheel ALL=(ALL:ALL) ALL/s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
$onroot sed -i -e '/NoExtract/c\NoExtract = usr/share/fonts/noto* !*NotoSans-* !*NotoSansMono-*' -e '/Color/s/#Color/Color/' -e '/ParallelDownloads = 5/s/#ParallelDownloads = 5/ParallelDownloads = 4/' /etc/pacman.conf
$onroot sed -i '/#MAKEFLAGS="-j2"/s/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/' /etc/makepkg.conf

$onroot echo -e 'vm.swappiness=10' > /mnt/etc/sysctl.d/99-swappiness.conf

procmeninfo=$(grep MemTotal /proc/meminfo | awk  '{print $2}')
A=$(expr $procmeninfo / 2)
MB=$(expr $A / 1024)
$onroot echo -e 'zram' > /mnt/etc/modules-load.d/zram.conf
$onroot cat << EOF > /mnt/etc/udev/rules.d/99-zram.rules
ACTION=="add", KERNEL=="zram0", ATTR{comp_algorithm}="zstd", ATTR{disksize}="${MB}M", RUN="/usr/bin/mkswap -U clear /dev/%k", TAG+="systemd"
EOF
$onroot sed -i '$a /dev/zram0 none swap defaults,pri=100 0 0' /etc/fstab

L='blacklist'
$onroot echo -e "$L iTCO_wdt\n$L sp5100_tco\n$L pcspkr\n$L mousedev\n$L mac_hid\n$L parport_pc\n$L floppy\n$L joydev\n$L pata_acpi\n$L irda\n$L yenta_socket\n$L ns558\n$L ppa\n$L 3c59x\n$L sbp2\n$L lp\n$L pnp\n$L 3c503" > /mnt/etc/modprobe.d/blacklist.conf

$onroot pacman -S wayland xorg-xwayland qt6-wayland --noconfirm --needed
$onroot pacman -S vulkan-radeon vulkan-nouveau mesa-vdpau libva-mesa-driver --noconfirm --needed

$onroot pacman -S pipewire-jack pipewire gst-plugin-pipewire pipewire-audio wireplumber gst-libav ffmpeg4.4 --noconfirm --needed

$onroot pacman -S plasma-desktop --noconfirm --needed
$onroot pacman -S plasma-pa plasma-nm kscreen breeze-gtk plasma-systemmonitor gtk3 kde-gtk-config --noconfirm --needed
$onroot pacman -S dolphin ark falkon gwenview kate kcalc konsole ktorrent okular spectacle --noconfirm --needed

$onroot pacman -S p7zip ttf-ubuntu-font-family neofetch --noconfirm --needed
$onroot pacman -S sddm sddm-kcm --noconfirm --needed; $onroot systemctl enable sddm.service

$onroot su - $nombre -c 'echo -e "#!/bin/bash\n\nB=\$(dirname \$0)\nE=\$(pwd)\n\nsudo pacman -S git go --noconfirm --needed\ngit clone https://aur.archlinux.org/yay.git; cd yay; makepkg -si; cd \$E\n\nrm -rf \$B/yay\nrm \$0" > ~/yay.sh'
$onroot su - $nombre -c "chmod 700 ~/yay.sh"

$onroot su - $nombre -c "mkdir ~/.config"
$onroot su - $nombre -c "echo -e '[Layout]\nLayoutList=es\nUse=true\n' > ~/.config/kxkbrc"; $onroot su - $nombre -c "echo -e '[Wallet]\nEnabled=false\n' > ~/.config/kwalletrc"; $onroot su - $nombre -c "echo -e '[Basic Settings]\nIndexing-Enabled=false\n' > ~/.config/baloofilerc"; $onroot su - $nombre -c "echo -e '[Plugins]\nbaloosearchEnabled=false\n' > ~/.config/krunnerrc"
$onroot su - $nombre -c "chmod -R go-rwx ~/.config" #$onroot su - $nombre -c 'chmod -R 700 ~/.config'

$onroot btrfs subvolume snapshot / "/dArch/root(1)"
$onroot btrfs subvolume snapshot /home  "/dArch/home(1)"

rm $0
umount -R /mnt
reboot
