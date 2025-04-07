This is used to automate installation of the [Chimera Linux](https://chimera-linux.org).

### The chosen disk is divided in 2 partitions:
- boot (also contains EFI) - 1 Gb - unencrypted FAT32
- root - the rest of the disk - encrypted [LUKS](https://en.wikipedia.org/wiki/Linux_Unified_Key_Setup) without [LVM](https://en.wikipedia.org/wiki/Logical_volume_management), [F2FS](https://en.wikipedia.org/wiki/F2FS) formatted

### Commands order:
```
apk add bash wget
wget https://raw.githubusercontent.com/rustamft/chimera-installer/refs/heads/main/chimera-installer.sh -O 1.sh
chmod +x 1.sh
./1.sh
```

If you have any questions, please refer to the [Chimera Linux Documentation](https://chimera-linux.org/docs).
