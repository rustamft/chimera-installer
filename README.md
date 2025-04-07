This is used to automate installation of Chimera Linux.

### The chosen disk is divided in 2 partitions:
- boot (also contains EFI) - 1 Gb - unencrypted FAT32
- root - the rest of the disk - encrypted LUKS without LVM, F2FS formatted

### Commands order:
```
apk add bash wget
wget https://raw.githubusercontent.com/rustamft/chimera-installer/refs/heads/main/chimera-installer.sh -O 1.sh
chmod +x 1.sh
./1.sh
```
