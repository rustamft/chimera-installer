#!/bin/bash

cat << EOF
#################################################################
###                                                           ###
###      Wellcome to the Chimera Linux install script!        ###
###                                                           ###
###                         WARNING!                          ###
###   The script will destroy all data on a disk you choose   ###
###                                                           ###
#################################################################

Your current disks and partitions:

EOF
lsblk -I 8,253,254,259
echo ""
while [[ -z $disk ]] || [[ ! -e /dev/$disk ]]; do
  read -p "Enter a valid disk name (e.g. sda or nvme0n1): " disk
done
if [[ $disk == *"nvme"* ]]; then
  partition_number_prefix="p"
fi
disk_partition_1="${disk}${partition_number_prefix}1"
disk_partition_2="${disk}${partition_number_prefix}2"
while [[ -z $password_encryption ]] || [[ $password_encryption != $password_encryption_confirmation ]]; do
  read -s -p "Enter a password for the ${disk_partition_2} partition encryption: " password_encryption
  printf "\n"
  read -s -p "Please repeat to confirm: " password_encryption_confirmation
  printf "\n"
done
while [[ -z $user_name ]]; do
  read -p "Enter a new administrator name: " user_name
  printf "\n"
done
while [[ -z $password_user ]] || [[ $password_user != $password_user_confirmation ]]; do
  read -s -p "Enter the administrator password: " password_user
  printf "\n"
  read -s -p "Please repeat to confirm: " password_user_confirmation
  printf "\n"
done
while [[ -z $host_name ]]; do
  read -p "Enter the host name: " host_name
  printf "\n"
done
packages="grub-x86_64-efi cryptsetup-scripts dbus networkmanager bluez pipewire xserver-xorg-minimal"
while [[ $kernel_type != "lts" ]] && [[ $kernel_type != "stable" ]]; do
  printf "Choose kernel type:\n  1) LTS\n  2) Stable\n"
  read kernel_type
  case $kernel_type in
    "1")
      kernel_type="lts"
      packages="$packages linux-lts"
      ;;
    "2")
      kernel_type="stable"
      packages="$packages linux-stable"
      ;;
    *)
      printf "This is not an option\n"
      unset desktop_environment ;;
  esac
done
while [[ -z $desktop_environment ]]; do
  printf "Choose installation type:\n  1) Only basic services for a desktop environment\n  2) GNOME\n  3) KDE\n"
  read desktop_environment
  case $desktop_environment in
    "1")
      desktop_environment="Basic" ;;
    "2")
      desktop_environment="GNOME"
      packages="$packages gdm gnome tlp"
      ;;
    "3")
      desktop_environment="KDE"
      packages="$packages sddm plasma-desktop tlp"
      ;;
    *)
      printf "This is not an option\n"
      unset desktop_environment ;;
  esac
done
while [[ -z $is_flatpak_required ]]; do
  read -p "Is Flatpak installation required? [Y/n] " is_flatpak_required
  case $is_flatpak_required in
    ""|"Y"|"y")
      is_flatpak_required=true
      packages="$packages flatpak"
      ;;
    "N"|"n")
      is_flatpak_required=false ;;
    *)
      printf "This is not an option\n"
      unset is_flatpak_required
      ;;
  esac
done
while [[ -z $is_swap_required ]]; do
  read -p "Would you like zRAM and SWAP to be configured? [Y/n] " is_swap_required
  case $is_swap_required in
    ""|"Y"|"y")
      is_swap_required=true
      while [[ ! $swap_size =~ '^[0-9]+$' ]]; do
        read -p "Swap size (Gb): " swap_size
      done
      ;;
    "N"|"n")
      is_swap_required=false ;;
    *)
      printf "This is not an option\n"
      unset is_swap_required
      ;;
  esac
done
wipefs -a /dev/$disk
fdisk /dev/$disk << EOF
g
n
1

+1000M
n
2


w
q
EOF
mkfs.vfat /dev/$disk_partition_1
echo -n $password_encryption | cryptsetup luksFormat /dev/$disk_partition_2 -
echo -n $password_encryption | cryptsetup luksOpen /dev/$disk_partition_2 cryptroot -
mkfs.f2fs /dev/mapper/cryptroot
if [[ ! -e /dev/$disk_partition_1 ]] || [[ ! -e /dev/$disk_partition_2 ]] || [[ ! -e /dev/mapper/cryptroot ]]; then
  echo "${disk} is not partitioned correctly"
  exit
fi
mkdir -p /media/root/boot/efi
mount /dev/mapper/cryptroot /media/root
mount /dev/$disk_partition_1 /media/root/boot
chmod 755 /media/root
chimera-bootstrap /media/root
chimera-chroot /media/root << EOF
echo -n $password_user | passwd --stdin root
useradd $user_name
echo -n $password_user | passwd --stdin $user_name
usermod -a -G wheel,kvm,plugdev $user_name
apk add $packages
dinitctl enable networkmanager
dinitctl enable bluetoothd
case $desktop_environment in
  "GNOME")
    dinitctl enable gdm ;;
  "KDE")
    dinitctl enable sddm ;;
esac
if $is_flatpak_required; then
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
fi
if $is_swap_required; then
  fallocate -l ${swap_size}G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
fi
echo $host_name > /etc/hostname
genfstab / >> /etc/fstab
echo cryptroot /dev/$disk_partition_2 none luks > /etc/crypttab
uuid=$(blkid -o value -s UUID /dev/mapper/cryptroot)
appendix="cryptdevice=UUID=\${uuid}:cryptroot root=\/dev\/mapper\/cryptroot"
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& \${appendix}/" /etc/default/grub
sed -i '/GRUB_ENABLE_CRYPTODISK=y/s/^#//g' /etc/default/grub
update-initramfs -c -k all
grub-install --target=x86_64-efi --efi-directory=/boot/efi
update-grub
EOF
umount -R /media/root
cryptsetup luksClose /dev/mapper/cryptroot
cat << EOF

###########################################
###                                     ###
###   Chimera Linux is ready to boot!   ###
###                                     ###
###########################################
EOF
