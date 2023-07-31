#!/bin/bash
#
apt update
dpkg-reconfigure locales tzdata keyboard-configuration console-setup
apt install -y vim git

apt install --yes dosfstools

mkdosfs -F 32 -s 1 -n EFI ${DISK}-part1
mkdir /boot/efi
echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}-part1) \
    /boot/efi vfat defaults 0 0 >> /etc/fstab
sync;sleep 1;mount /boot/efi
mkdir /boot/efi/grub /boot/grub
echo /boot/efi/grub /boot/grub none defaults,bind 0 0 >> /etc/fstab
sync;sleep 1; mount /boot/grub


apt install --yes \
    grub-efi-amd64 grub-efi-amd64-signed linux-image-generic \
    shim-signed zfs-initramfs

apt purge --yes os-prober
passwd
apt install --yes cryptsetup openssh-server

echo swap ${DISK}-part2 /dev/urandom \
      swap,cipher=aes-xts-plain64:sha256,size=512 >> /etc/crypttab
echo /dev/mapper/swap none swap defaults 0 0 >> /etc/fstab
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount
addgroup --system lpadmin
addgroup --system lxd
addgroup --system sambashare

grub-probe /boot

update-initramfs -c -k all

