# Installing Arch Linux

## Introduction

In this guide I'll show how to install Arch Linux with **BTRFS** on an **UEFI system**. I'll comment each step to make it understandable. Apart from the basic terminal installation I'll add steps to install video drivers, a desktop environment and to configure arch for gaming.

<br>

I won't prepare the system for **secure boot** because the procedure of custom key enrollment in the BIOS is dangerous and can lead to a bricked system, read the warnings [here](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Creating_and_enrolling_keys). If you are wondering why not using the default OEM keys in the BIOS, it's because they will make secure boot useless by being most likely not enough secure, as the arch wiki [states](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Implementing_Secure_Boot).

<br> 

I won't encrypt the system because I don't need it and in my opinion has few uses cases in which is actually needed ( you can always encrypt sensible information with **gpg**). Also the boot would become inevitably **slower**.

<br>

I'll skip the Arch ISO download, gpg signature check and installation media preparation.

<br>

I'll use a **wired** connection, so no wireless configuration steps will be shown. If you want to connect to wifi, you can either launch `wifi-menu` from the terminal which is a TGUI or use [iwctl](https://wiki.archlinux.org/title/Iwd#iwctl).

<br>

## Preliminary steps

Check that we are in UEFI mode

```bash
# If this command prints 64 or 32 then you are in UEFI
cat /sys/firmware/efi/fw_platform_size
```

<br>

Check the internet connection  

```bash
ping -c 5 archlinux.org 
```

<br>

Check the system clock just in case

```bash
# Check if ntp is active and if the time is right
timedatectl
```

<br>

## Main installation

### Disk Partitioning

I will make 2 partitions:  

| Number | Type | Size |
| --- | --- | --- |
| 1 | EFI | 512 Mb |
| 2 | Linux Filesystem | 99.5Gb \(all of the remaining space \) |  

<br>

```bash
# Check the drive name. Mine is /dev/nvme0n1
# If you have an hdd is something like sdax
fdisk -l

# Invoke fdisk to partition
fdisk /dev/nvme0n1

# Now press the following commands, when i write ENTER press enter
g
ENTER
n
ENTER
ENTER
ENTER
+512M
ENTER
t
ENTER
ENTER
1
ENTER
n
ENTER
ENTER
ENTER # If you don't want to use all the space then select the size by writing +XG ( eg: to make a 10GB partition +10G )
p
ENTER # Now check if you got the partitions right

# If so write the changes
w
ENTER

# If not you can quit without saving and redo from the beginning
q
ENTER
```

<br>

### Disk formatting

As a file system I've chosen to use **BTRFS** which has evolved quite a lot during the years. It has a set of incredible functionalities but is most known for its **Copy on Write** feature which enables it to make system snapshots in a blink of a an eye and to save a lot of disk space, which can be even saved to a greater extent by eanbling **compression**. Also it enables the creation of **subvolumes** which can be individually snapshotted. Learn more [here](https://wiki.archlinux.org/title/Btrfs)

```bash
# Find the efi partition with fdisk -l or lsblk. For me it's /dev/nvme0n1p1 and format it.
mkfs.fat -F 32 /dev/nvme0n1p1

# Find the root partition. For me it's /dev/nvme0n1p2 and format it. I will use BTRFS.
mkfs.btrfs /dev/nvme0n1p2

# Mount the root fs to make it accessible
mount /dev/nvme0n1p2 /mnt
```

<br>

### Disk mounting

```bash
# Create the subvolumes, in my case I choose to make a subvolume for / and one for /home. Subvolumes are identified by prepending @
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home

# Unmount the root fs
umount /mnt
```

<br>

For this guide I'll compress the btrfs subvolumes with **Zstd**, which has proven to be [a good algorithm among the choices](https://www.phoronix.com/review/btrfs-zstd-compress)  

```bash
# Mount the root and home subvolume. If you don't want compression just remove the compress option.
mount -o compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt
mkdir -p /mnt/home
mount -o compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
```

<br>

Now we have to mount the efi partition. In general there are 2 main mountpoints to use: `/efi` or `/boot` but in this configuration i am **forced** to use `/efi`, because by choosing `/boot` we could experience a **system crash** when trying to restore `@root` to a previous state after kernel updates. This happens because boot files such as the kernel aren't stored on `@root` but on the efi partition and hence they can't be saved when snapshotting `@root`. Also this choice grants separation of concerns and also is good if one wants to encrypt `/boot`, since you can't encrypt efi files. Learn more [here](https://wiki.archlinux.org/title/EFI_system_partition#Typical_mount_points)

```bash
mkdir -p /mnt/efi
mount /dev/nvme0n1p1 /mnt/efi
```

<br>

### ArchInstall

Now we can run the archinstall helper

```bash
archinstall
```

Set the following options then select `install`

```
Mirrors:                  select mirror closer to you
Locales:                  select locale defined by region and keyboard layout
Disk configuration:       select pre-mounted configuration
                          enter the root directory of mounted devices /mnt
Disk encryption:          I generally don't use it -- see above
Bootloader:               grub
Unified kernel images:    false
Swap:                     true
Hostname:                 default, or change it
Root password:            set a root password
User account:             add a user and password, make this a superuser
Profile:                  select install type, desktop environment, gpu drivers, and greeter
Gpu drivers:              open source for amd and intel, proprietary for nvidia
Greeter:                  sddm
Audio:                    pipewire
Kernels:                  default
Additional packages:      select any additional packages you want (can install later too)
Network configuration:    networkmanager
Timezone:                 select your timezone
```
```
```


### Bootloader

After the archinstall tool finishes, it'll ask to chroot into the install, select yes


```sh
# Install grub and dependencies/tools
# "grub" the bootloader
# "efibootmgr" needed to install grub
# "grub-btrfs" adds btrfs support for the grub bootloader and enables the user to directly boot from snapshots
# "inotify-tools" used by grub btrfsd daemon to automatically spot new snapshots and update grub entries
# "btrfs-progs" user-space utilities for file system management
pacman -Sy grub efibootmgr btrfs-progs grub-btrfs inotify-tools

# Deploy grub
grub-install --target=x86_64-efi --efi-directory=/efi --booloader-id=GRUB

# Generate the grub configuration
grub-mkconfig -o /boot/grub/grub.cfg
```


### Reboot

```bash
# Exit from the chroot
exit

# Reboot the system and unplug the installation media
reboot
```


## Post-Install Steps

### Automatic snapshot boot entries update

Edit **`grub-btrfsd`** service to enable **automatic grub entries update** each time a snapshot is created. Because I will use timeshift i am going to replace `ExecStart=...` with `ExecStart=/usr/bin/grub-btrfsd --syslog --timeshift-auto`. If you don't use timeshift or prefer to manually update the entries then lookup [here](https://github.com/Antynea/grub-btrfs)  

```bash 
sudo systemctl edit --full grub-btrfsd

# Enable grub-btrfsd service to run on boot
sudo systemctl enable grub-btrfsd
```
