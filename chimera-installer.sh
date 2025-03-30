echo "#################################################################"
echo "###                                                           ###"
echo "###      Wellcome to the Chimera Linux install script!        ###"
echo "###                                                           ###"
echo "###                         WARNING!                          ###"
echo "###   The script will destroy all data on a disk you choose   ###"
echo "###                                                           ###"
echo "#################################################################"
echo "Your current disks and partitions:"
lsblk -I 8,253,254,259
while [[ -z $disk ]] || [[ ! -e /dev/$disk ]]; do
  read -p "Enter a valid disk name (e.g. sda or nvme0n1): " disk
done
if [[ $disk == *"nvme"* ]]; then
  disk_partition_1="${disk}p1"
  disk_partition_2="${disk}p2"
else
  disk_partition_1="${disk}1"
  disk_partition_2="${disk}2"
fi
while [[ -z $password ]] || [[ $password != $password_confirmation ]]; do
  read -s -p "Enter a password for the ${disk_partition_2} partition encryption: " password
  printf "\n"
  read -s -p "Please repeat to confirm: " password_confirmation
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
echo -n $password | cryptsetup luksFormat /dev/$disk_partition_2 -
echo -n $password | cryptsetup luksOpen /dev/$disk_partition_2 cryptroot -
mkfs.vfat $disk_partition_1
mkfs.f2fs $disk_partition_2
if [[ ! -e /dev/$disk_partition_1 ]] || [[ ! -e /dev/$disk_partition_2 ]] || [[ ! -e /dev/mapper/cryptroot ]]; then
  echo "${disk} is not partitioned correctly"
  exit
fi
mkdir /media/root
mkdir /media/root/boot
mount /dev/mapper/cryptroot /media/root
mount /dev/$disk_partition_1 /media/root/boot
chmod 755 /media/root
chimera-bootstrap /media/root
chimera-chroot /media/root << EOF
  apk add linux-$kernel_type
  genfstab / >> /etc/fstab
EOF
