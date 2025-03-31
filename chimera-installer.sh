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
while [[ -z $password_root ]] || [[ $password_root != $password_root_confirmation ]]; do
  read -s -p "Enter the root password: " password_root
  printf "\n"
  read -s -p "Please repeat to confirm: " password_root_confirmation
  printf "\n"
done
while [[ -z $is_swap_required ]]; do
  read -p "Would you like zRAM and SWAP to be configured? [Y/n] " is_swap_required
  case $is_swap_required in
    ""|"Y"|"y")
      is_swap_required=true ;;
    "N"|"n")
      is_swap_required=false ;;
    *)
      printf "This is not an option\n"
      unset is_swap_required
      ;;
  esac
done
while [[ $kernel_type != "lts" ]] && [[ $kernel_type != "stable" ]]; do
  read -p "What kernel would you like? [lts/stable]: " kernel_type
done
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
echo -n $password_root | passwd --stdin root
apk add linux-$kernel_type grub-x86_64-efi
genfstab / >> /etc/fstab
update-initramfs -c -k all
grub-install --efi-directory=/boot/efi
update-grub
EOF
