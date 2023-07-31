#!/bin/bash

update-grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=ubuntu --recheck --no-floppy
mkdir /etc/zfs/zfs-list.cache
touch /etc/zfs/zfs-list.cache/bpool
touch /etc/zfs/zfs-list.cache/rpool
zed -F &
sleep 3

sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/*
exit
