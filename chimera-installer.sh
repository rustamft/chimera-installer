#!/bin/sh -e

umount_all() {
  umount -R /media/root > /dev/null 2>&1 || true
  cryptsetup luksClose /dev/mapper/cryptroot > /dev/null 2>&1 || true
}

clear_user_choices() {
  unset disk password_encryption \
        password_encryption_confirmation \
        user_groups \
	    user_name \
	    password_admin \
	    host_name \
	    packages \
	    processor_microcode \
	    kernel_selection \
	    desktop_environment \
	    is_flatpak_required \
	    is_virtual_machine_manager_required \
	    file_system \
	    swap_size \
	    zram_size \
	    bootloader \
	    wipe_confirmation
}

set_defaults() {
  user_groups="wheel,plugdev"
  packages="cryptsetup-scripts dbus networkmanager networkmanager-openvpn bluez pipewire xserver-xorg-minimal xdg-user-dirs"
}

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
cat << EOF

######################
# User choices start #
######################

EOF
umount_all
clear_user_choices
set_defaults
echo ''
while [ -z "$disk" ] || [ ! -b "/dev/$disk" ]; do
  read -rp 'Enter a valid disk name (e.g. sda or nvme0n1): ' disk
done
case $disk in
  *'nvme'*) partition_number_prefix='p';;
esac
disk_partition_1="${disk}${partition_number_prefix}1"
disk_partition_2="${disk}${partition_number_prefix}2"
echo ''
while [ -z "$password_encryption" ]; do
  stty -echo; IFS= read -rp "Enter a password for the root (${disk_partition_2}) partition encryption: " password_encryption; stty echo; echo ''
  stty -echo; IFS= read -rp 'Please repeat to confirm: ' password_encryption_confirmation; stty echo; echo ''
  if [ "$password_encryption" != "$password_encryption_confirmation" ]; then echo 'The passwords do not match!'; unset password_encryption; fi
done
echo ''
while [ -z "$user_name" ]; do
  read -rp 'Enter a new administrator name: ' user_name
done
while [ -z "$password_admin" ]; do
  stty -echo; IFS= read -rp 'Enter the administrator password (also used for the root): ' password_admin; stty echo; echo ''
  stty -echo; IFS= read -rp 'Please repeat to confirm: ' password_admin_confirmation; stty echo; echo ''
  if [ "$password_admin" != "$password_admin_confirmation" ]; then echo 'The passwords do not match!'; unset password_admin; fi
done
unset password_admin_confirmation
echo ''
while [ -z "$host_name" ]; do
  read -rp 'Enter the host name: ' host_name
done
echo ''
while [ -z "$processor_microcode" ]; do
  printf 'Choose CPU microcode:\n  1) None\n  2) AMD\n  3) Intel\n'
  read -r processor_microcode
  case $processor_microcode in
    '1') ;;
    '2') packages="$packages ucode-amd";;
    '3') packages="$packages ucode-intel";;
    *) echo 'This is not an option!'; unset processor_microcode;;
  esac
done
echo ''
while [ -z "$kernel_selection" ]; do
  printf 'Choose kernels:\n  1) LTS\n  2) Stable\n  3) LTS and Stable\n'
  read -r kernel_selection
  case $kernel_selection in
    '1') packages="$packages linux-lts";;
    '2') packages="$packages linux-stable";;
    '3') packages="$packages linux-lts linux-stable";;
    *) echo 'This is not an option!'; unset kernel_selection;;
  esac
done
echo ''
while [ -z "$desktop_environment" ]; do
  printf 'Choose desktop environment:\n  1) None\n  2) GNOME\n  3) Minimal GNOME\n  4) KDE\n  5) Minimal KDE\n'
  read -r desktop_environment
  case $desktop_environment in
    '1') desktop_environment='none';;
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
    *) echo 'This is not an option!'; unset desktop_environment;;
  esac
done
echo ''
while [ -z "$is_flatpak_required" ]; do
  read -rp 'Is Flatpak installation required? [Y/n] ' is_flatpak_required
  case $is_flatpak_required in
    ''|'Y'|'y')
      is_flatpak_required=true
      packages="$packages flatpak"
      ;;
    'N'|'n') is_flatpak_required=false;;
    *) echo 'This is not an option!'; unset is_flatpak_required;;
  esac
done
echo ''
while [ -z "$is_virtual_machine_manager_required" ]; do
  read -rp 'Is Virtual Machine Manager installation required? [Y/n] ' is_virtual_machine_manager_required
  case $is_virtual_machine_manager_required in
    ''|'Y'|'y')
      is_virtual_machine_manager_required=true
      packages="$packages qemu-system-x86_64 libvirt virt-manager iptables spice-vdagent"
      user_groups="$user_groups,kvm,libvirt"
      ;;
    'N'|'n') is_virtual_machine_manager_required=false;;
    *) echo 'This is not an option!'; unset is_virtual_machine_manager_required;;
  esac
done
echo ''
while [ -z "$file_system" ]; do
  printf 'Choose file system for root partition:\n  1) btrfs\n  2) ext4\n  3) f2fs\n'
  read -r file_system
  case $file_system in
    '1') file_system='btrfs';;
    '2') file_system='ext4';;
    '3') file_system='f2fs';;
    *) echo 'This is not an option!'; unset file_system;;
  esac
done
echo ''
while ! [ "$swap_size" -ge 0 ] 2>/dev/null; do
  read -rp 'Swap size in Gb (type 0 for none): ' swap_size
done
echo ''
while ! [ "$zram_size" -ge 0 ] 2>/dev/null; do
  read -rp 'zRAM size in Gb (type 0 for none): ' zram_size
done
echo ''
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
    *) echo 'This is not an option!'; unset bootloader;;
  esac
done
cat << EOF

####################
# User choices end #
###########################
# Disk partitioning start #
###########################

EOF
unset wipe_confirmation
while [ -z "$wipe_confirmation" ]; do
  read -rp 'WARNING: All data on the disk are going to be destroyed right now. Are you sure you wish to proceed? [yes/no] ' wipe_confirmation
  case $wipe_confirmation in
    'yes') wipefs -a "/dev/$disk";;
    'no')
      clear_user_choices
      umount_all
      exit 0
      ;;
    *) echo 'This is not an option!'; unset wipe_confirmation;;
  esac
done
unset wipe_confirmation
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
mkfs.vfat -F 32 "/dev/$disk_partition_1"
echo -n "$password_encryption" | cryptsetup luksFormat -q "/dev/$disk_partition_2"
echo -n "$password_encryption" | cryptsetup luksOpen "/dev/$disk_partition_2" cryptroot
case $file_system in
  'btrfs') mkfs.btrfs -f /dev/mapper/cryptroot;;
  'ext4') mkfs.ext4 /dev/mapper/cryptroot;;
  'f2fs') mkfs.f2fs -f /dev/mapper/cryptroot;;
  *) printf "\nERROR: File system is not chosen\n\n"; exit 1;;
esac
if [ ! -e "/dev/$disk_partition_1" ] || [ ! -e "/dev/$disk_partition_2" ] || [ ! -e /dev/mapper/cryptroot ]; then
  printf "\nERROR: Disk $disk partitioning failed\n\n"
  lsblk -I 8,253,254,259
  exit 1
fi
cat << EOF

#########################
# Disk partitioning end #
############################
# Partition mounting start #
############################

EOF
mkdir -p /media/root \
&& mount /dev/mapper/cryptroot /media/root \
&& chmod 755 /media/root \
&& mkdir -p /media/root/boot \
&& mount "/dev/$disk_partition_1" /media/root/boot \
|| (printf "\nERROR: Partition mounting failed\n\n"; exit 1)
cat << EOF

##########################
# Partition mounting end #
##########################
# Installation start #
######################

EOF
chimera-bootstrap /media/root
chimera-chroot /media/root << EOF
echo -n "$password_admin" | passwd --stdin root
useradd --create-home "$user_name"
echo -n "$password_admin" | passwd --stdin "$user_name"
echo "$host_name" > /etc/hostname
echo y | apk add chimera-repo-user
apk update
echo y | apk add $packages
usermod -aG "$user_groups" "$user_name"
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
  dinitctl -o enable spice-vdagentd
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
    gen-systemd-boot
    ;;
esac
EOF
cat << EOF

####################
# Installation end #
####################
# Finalizing start #
####################

EOF
clear_user_choices
rm -f /media/root/.sh_history
umount_all
cat << EOF

##################
# Finalizing end #
##################

EOF
cat << EOF

###########################################
###                                     ###
###   Chimera Linux is ready to boot!   ###
###                                     ###
###########################################

EOF
