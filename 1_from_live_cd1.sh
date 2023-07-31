#!/bin/bash

#### MAKE SURE TO EDIT THE VALUES IN THE VARIABLES BELOW
export DISK="/dev/disk/by-id/XXX"
export hostname="zfstest"
export NetIF="enp0s3"

# Swapsize autocalculated to be = Mem size
export SWAPSIZE=`free --giga|grep Mem|awk '{OFS="";print "+", $2 ,"G"}'`

apt install --yes debootstrap gdisk zfsutils-linux vim git

systemctl stop zed
swapoff --all

wipefs -a $DISK
blkdiscard -f $DISK
sgdisk --zap-all $DISK
sgdisk     -n1:1M:+512M   -t1:EF00 $DISK
sgdisk     -n2:0:${SWAPSIZE}    -t2:8200 $DISK
sgdisk     -n3:0:+2G      -t3:BE00 $DISK
sgdisk     -n4:0:0        -t4:BF00 $DISK

sync;sleep 2

zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -o cachefile=/etc/zfs/zpool.cache \
    -o compatibility=grub2 \
    -o feature@livelist=enabled \
    -o feature@zpool_checkpoint=enabled \
    -O devices=off \
    -O acltype=posixacl -O xattr=sa \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off -O mountpoint=/boot -R /mnt \
    bpool ${DISK}-part3

zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -O encryption=on -O keylocation=prompt -O keyformat=passphrase \
    -O acltype=posixacl -O xattr=sa -O dnodesize=auto \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off -O mountpoint=/ -R /mnt \
    rpool ${DISK}-part4

zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

zpool list
sleep 5

UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null |
    tr -dc 'a-z0-9' | cut -c-6)

zfs create -o mountpoint=/ \
    -o com.ubuntu.zsys:bootfs=yes \
    -o com.ubuntu.zsys:last-used=$(date +%s) rpool/ROOT/ubuntu_$UUID

zfs create -o mountpoint=/boot bpool/BOOT/ubuntu_$UUID

zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off \
    rpool/ROOT/ubuntu_$UUID/usr
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off \
    rpool/ROOT/ubuntu_$UUID/var
zfs create rpool/ROOT/ubuntu_$UUID/var/lib
zfs create rpool/ROOT/ubuntu_$UUID/var/log
zfs create rpool/ROOT/ubuntu_$UUID/var/spool

zfs create -o canmount=off -o mountpoint=/ \
    rpool/USERDATA
zfs create -o com.ubuntu.zsys:bootfs-datasets=rpool/ROOT/ubuntu_$UUID \
    -o canmount=on -o mountpoint=/root \
    rpool/USERDATA/root_$UUID
chmod 700 /mnt/root
zfs create rpool/ROOT/ubuntu_$UUID/var/cache
zfs create rpool/ROOT/ubuntu_$UUID/var/lib/nfs
zfs create rpool/ROOT/ubuntu_$UUID/var/tmp
chmod 1777 /mnt/var/tmp

zfs create rpool/ROOT/ubuntu_$UUID/var/lib/apt
zfs create rpool/ROOT/ubuntu_$UUID/var/lib/dpkg
zfs create rpool/ROOT/ubuntu_$UUID/usr/local
zfs create rpool/ROOT/ubuntu_$UUID/var/lib/AccountsService
zfs create rpool/ROOT/ubuntu_$UUID/var/lib/NetworkManager
zfs create rpool/ROOT/ubuntu_$UUID/var/snap
zfs create -o com.ubuntu.zsys:bootfs=no \
    rpool/ROOT/ubuntu_$UUID/tmp
chmod 1777 /mnt/tmp

mkdir /mnt/run; sync
mount -t tmpfs tmpfs /mnt/run
mkdir /mnt/run/lock;sync

debootstrap lunar /mnt

mkdir /mnt/etc/zfs; sync
cp /etc/zfs/zpool.cache /mnt/etc/zfs/
apt install -y vim
hostname $hostname
hostname > /mnt/etc/hostname
echo "127.0.0.1 $hostname" >>/mnt/etc/hosts

echo "network:" >>/mnt/etc/netplan/01-netcfg.yaml
echo "  version: 2" >>/mnt/etc/netplan/01-netcfg.yaml
echo "  ethernets:" >>/mnt/etc/netplan/01-netcfg.yaml
echo "    ${NetIF}:" >>/mnt/etc/netplan/01-netcfg.yaml
echo "      dhcp4: true" >>/mnt/etc/netplan/01-netcfg.yaml

echo "deb http://archive.ubuntu.com/ubuntu lunar main restricted universe multiverse" >/mnt/etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu lunar-updates main restricted universe multiverse" >>/mnt/etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu lunar-backports main restricted universe multiverse" >>/mnt/etc/apt/sources.list
echo "deb http://security.ubuntu.com/ubuntu lunar-security main restricted universe multiverse" >>/mnt/etc/apt/sources.list

mount --make-private --rbind /dev  /mnt/dev
mount --make-private --rbind /proc /mnt/proc
mount --make-private --rbind /sys  /mnt/sys
cp -a /root/zfs_on_root /mnt/root/
chroot /mnt /usr/bin/env DISK=$DISK UUID=$UUID bash --login