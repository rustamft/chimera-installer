#!/bin/sh

cat << EOF
#################################################################
###                                                           ###
###       Welcome to the Chimera Linux install script!        ###
###                                                           ###
###                         WARNING!                          ###
###   The script will destroy all data on a disk you choose   ###
###                                                           ###
#################################################################

Your current disks and partitions:

EOF
lsblk -I 8,253,254,259
echo ''

# User choices

while [ -z "$disk" ] || [ ! -e "/dev/$disk" ]; do
  read -rp 'Enter a valid disk name (e.g. sda or nvme0n1): ' disk
done
case $disk in
  *'nvme'*) partition_number_prefix='p';;
esac
disk_partition_1="${disk}${partition_number_prefix}1"
disk_partition_2="${disk}${partition_number_prefix}2"
while [ -z "$password_encryption" ] || [ "$password_encryption" != "$password_encryption_confirmation" ]; do
  stty -echo; IFS= read -rp "Enter a password for the ${disk_partition_2} partition encryption: " password_encryption; stty echo
  printf '\n'
  stty -echo; IFS= read -rp 'Please repeat to confirm: ' password_encryption_confirmation; stty echo
  printf '\n'
done
unset password_encryption_confirmation
while [ -z "$user_name" ]; do
  read -rp 'Enter a new administrator name: ' user_name
done
while [ -z "$password_admin" ] || [ "$password_admin" != "$password_admin_confirmation" ]; do
  stty -echo; IFS= read -rp 'Enter the administrator password (also used for the root): ' password_admin; stty echo
  printf '\n'
  stty -echo; IFS= read -rp 'Please repeat to confirm: ' password_admin_confirmation; stty echo
  printf '\n'
done
unset password_admin_confirmation
while [ -z "$host_name" ]; do
  read -rp 'Enter the host name: ' host_name
done
while [ -z "$processor_microcode" ]; do
  printf 'Choose CPU microcode:\n  1) None\n  2) AMD\n  3) Intel\n'
  read -r processor_microcode
  case $processor_microcode in
    '1') ;;
    '2') packages="$packages ucode-amd";;
    '3') packages="$packages ucode-intel";;
    *)
      printf 'This is not an option\n'
      unset processor_microcode
      ;;
  esac
done
while [ -z "$kernel_selection" ]; do
  printf 'Choose kernels:\n  1) LTS\n  2) Stable\n 3) LTS and Stable\n'
  read -r kernel_selection
  case $kernel_selection in
    '1') packages="$packages linux-lts";;
    '2') packages="$packages linux-stable";;
    '3') packages="$packages linux-lts linux-stable";;
    *)
      printf 'This is not an option\n'
      unset kernel_selection
      ;;
  esac
done
while [ -z "$desktop_environment" ]; do
  printf 'Choose desktop environment:\n  1) None\n  2) GNOME\n  3) Minimal GNOME\n  4) KDE\n  5) Minimal KDE\n'
  read -r desktop_environment
  case $desktop_environment in
    '1')
      desktop_environment='none'
      ;;
    '2')
      desktop_environment='gnome'
      packages="$packages gnome gnome-shell-extensions gnome-system-monitor gnome-tweaks file-roller nautilus kitty wl-clipboard"
      ;;
    '3')
      desktop_environment='gnome-minimal'
      packages="$packages gnome !gnome-apps gnome-shell-extensions gnome-system-monitor gnome-tweaks file-roller nautilus kitty wl-clipboard"
      ;;
    '4')
      desktop_environment='kde'
      packages="$packages sddm plasma-desktop kitty wl-clipboard"
      ;;
    '5')
      desktop_environment='kde-minimal'
      packages="$packages sddm plasma-desktop !plasma-desktop-x11-meta !plasma-desktop-apps-meta !plasma-desktop-games-meta !plasma-desktop-multimedia-meta !plasma-desktop-devtools-meta !plasma-desktop-accessibility-meta !plasma-desktop-kdepim-meta ark dolphin kitty wl-clipboard"
      ;;
    *)
      printf 'This is not an option\n'
      unset desktop_environment
      ;;
  esac
done
while [ -z "$is_flatpak_required" ]; do
  read -rp 'Is Flatpak installation required? [Y/n] ' is_flatpak_required
  case $is_flatpak_required in
    ''|'Y'|'y')
      is_flatpak_required=true
      packages="$packages flatpak"
      ;;
    'N'|'n')
      is_flatpak_required=false
      ;;
    *)
      printf 'This is not an option\n'
      unset is_flatpak_required
      ;;
  esac
done
while [ -z "$is_virtual_machine_manager_required" ]; do
  read -rp 'Is Virtual Machine Manager installation required? [Y/n] ' is_virtual_machine_manager_required
  case $is_virtual_machine_manager_required in
    ''|'Y'|'y')
      is_virtual_machine_manager_required=true
      packages="$packages qemu-system-x86_64 libvirt virt-manager iptables"
      ;;
    'N'|'n')
      is_virtual_machine_manager_required=false
      ;;
    *)
      printf 'This is not an option\n'
      unset is_virtual_machine_manager_required
      ;;
  esac
done
while ! [ "$swap_size" -ge 0 ] 2>/dev/null; do
  read -rp 'Swap size in Gb (type 0 for none): ' swap_size
done
while ! [ "$zram_size" -ge 0 ] 2>/dev/null; do
  read -rp 'zRAM size in Gb (type 0 for none): ' zram_size
done
while [ -z "$bootloader" ]; do
  printf 'Choose bootloader:\n  1) GRUB\n  2) systemd-boot\n'
  read -r bootloader
  case $bootloader in
    '1')
      bootloader='grub'
      packages="$packages grub-x86_64-efi"
      ;;
    '2')
      bootloader='systemd-boot'
      packages="$packages systemd-boot"
      ;;
    *)
      printf 'This is not an option\n'
      unset bootloader
      ;;
  esac
done

# Disk partitioning

wipefs -a "/dev/$disk"
fdisk "/dev/$disk" << EOF
g
n
1

+1000M
t
1
n
2


w
q
EOF
mkfs.vfat "/dev/$disk_partition_1"
echo -n "$password_encryption" | cryptsetup luksFormat "/dev/$disk_partition_2"
echo -n "$password_encryption" | cryptsetup luksOpen "/dev/$disk_partition_2" cryptroot
mkfs.f2fs /dev/mapper/cryptroot
if [ ! -e "/dev/$disk_partition_1" ] || [ ! -e "/dev/$disk_partition_2" ] || [ ! -e /dev/mapper/cryptroot ]; then
  echo "$disk is not partitioned correctly"
  exit 1
fi

# Partition mounting

mkdir /media/root
mount /dev/mapper/cryptroot /media/root
chmod 755 /media/root
mkdir /media/root/boot
mount "/dev/$disk_partition_1" /media/root/boot

# Installation

chimera-bootstrap /media/root
chimera-chroot /media/root << EOF
echo -n "$password_admin" | passwd --stdin root
useradd --create-home -G wheel,kvm,plugdev "$user_name"
echo -n "$password_admin" | passwd --stdin "$user_name"
echo "$host_name" > /etc/hostname
echo y | apk add chimera-repo-user
apk update
echo y | apk add cryptsetup-scripts dbus networkmanager networkmanager-openvpn bluez pipewire xserver-xorg-minimal xdg-user-dirs $packages
dinitctl -o enable networkmanager
dinitctl -o enable bluetoothd
case $desktop_environment in
  'gnome'|'gnome-minimal') dinitctl -o enable gdm;;
  'kde'|'kde-minimal') dinitctl -o enable sddm;;
esac
if $is_flatpak_required; then
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
if $is_virtual_machine_manager_required; then
  dinitctl -o enable virtqemud
  dinitctl -o enable virtstoraged
  dinitctl -o enable virtnetworkd
  dinitctl -o enable iptables
fi
genfstab -U / >> /etc/fstab
sed -i '' 's/ [^ ]* 0 / defaults 0 /' /etc/fstab
if [ "$swap_size" -gt 0 ]; then
  fallocate -l "${swap_size}G" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
fi
if [ "$zram_size" -gt 0 ]; then
  printf '#!/bin/sh\n\nmodprobe zram\nzramctl /dev/zram0 --algorithm zstd --size ${zram_size}G\nmkswap -U clear /dev/zram0\nswapon --discard --priority 100 /dev/zram0\n' > /etc/dinit.d/zram.sh
  chmod +x /etc/dinit.d/zram.sh
  printf 'type = scripted\ncommand = /etc/dinit.d/zram.sh\ndepends-on = local.target\n' > /etc/dinit.d/zram
  dinitctl -o enable zram
fi
disk_partition_2_uuid=$(blkid -o value -s UUID "/dev/$disk_partition_2")
echo "cryptroot UUID=\$disk_partition_2_uuid none luks" > /etc/crypttab
update-initramfs -c -k all
case $bootloader in
  'grub')
    echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
    grub-install --target=x86_64-efi --efi-directory=/boot
    update-grub
    ;;
  'systemd-boot')
    bootctl install
    sed -i '' '/timeout/s/^#//' /boot/loader/loader.conf
    echo 'options root=/dev/mapper/cryptroot' >> /boot/loader/loader.conf
    gen-systemd-boot
    ;;
esac
EOF

# Finalizing

unset password_encryption
unset password_admin
rm /media/root/.sh_history
umount -R /media/root
cryptsetup luksClose /dev/mapper/cryptroot
cat << EOF

###########################################
###                                     ###
###   Chimera Linux is ready to boot!   ###
###                                     ###
###########################################
EOF
