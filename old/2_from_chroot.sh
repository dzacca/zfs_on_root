#!/bin/bash
#
apt update
dpkg-reconfigure locales tzdata keyboard-configuration 
apt install -y vim git dosfstools cryptsetup openssh-server

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
echo "Setting temporary root password:"
passwd

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

sed -i 's/^GRUB_TIMEOUT=0/GRUB_TIMEOUT=5/g' /etc/default/grub
sed -i '/GRUB_TIMEOUT=/a GRUB_RECORDFAIL_TIMEOUT=5' /etc/default/grub
sed -i 's/"quiet splash"/"quite splash init_on_alloc=0"/g' /etc/default/grub
sed -i 's/^#GRUB_TERMINAL/GRUB_TERMINAL/g' /etc/default/grub  
sync
update-grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=ubuntu --recheck --no-floppy
mkdir /etc/zfs/zfs-list.cache
touch /etc/zfs/zfs-list.cache/bpool
touch /etc/zfs/zfs-list.cache/rpool
zed -F &
sleep 3

sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/*
# need to exit from chroot now, temporarily disabled while testing the script
logout
