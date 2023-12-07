#!/bin/bash
#
########################
# Change ${RUN} to true to execute the script
RUN="false"

# Variables - Populate/tweak this before launching the script
export DISTRO="server" #server, desktop, kumuntu, xubuntu, budgie, MATE
export RELEASE="mantic"
export DISK="sda"                 # Enter the disk name only (sda, sdb, nvme1, etc)
export PASSPHRASE="SomeRandomKey" # Encryption passphrase for zroot
export PASSWORD="mypassword"      # temporary root password & password for ${USERNAME}
export HOSTNAME="myhost"          # hostname of the new machine
export USERNAME="myuser"          # user to create in the new machine
export NALA="true"                # Install and use nala instead of apt
export MOUNTPOINT="/mnt"          # debootstrap target location
export LOCALE="en_US.UTF-8"       # New install language setting.
export TIMEZONE="Europe/Rome"     # New install timezone setting.
export RTL8821CE="false"          # Download and install RTL8821CE drivers as the default ones are faulty

## Auto-reboot at the end of installation? (true/false)
REBOOT="false"

########################################################################
#### Enable/disable debug. Only used during the development phase.
DEBUG="false"
########################################################################
########################################################################
########################################################################
export GIT="/usr/bin/git"

if [[ ${RUN} =~ "false" ]]; then
  echo "Refusing to run as \$RUN is set to false"
  exit 1
fi

DISKID=/dev/disk/by-id/$(ls -al /dev/disk/by-id | grep ${DISK} | awk '{print $9}' | head -1)
export DISKID
DISK="/dev/${DISK}"
if [[ ${NALA} =~ "true" ]]; then
  export APT="/usr/bin/nala"
else
  export APT="/usr/bin/apt"
fi

source /etc/os-release
export ID
export BOOT_DISK="${DISKID}"
export BOOT_PART="1"
export BOOT_DEVICE="${BOOT_DISK}-part${BOOT_PART}"

export SWAP_DISK="${DISKID}"
export SWAP_PART="2"
export SWAP_DEVICE="${SWAP_DISK}-part${SWAP_PART}"

export POOL_DISK="${DISKID}"
export POOL_PART="3"
export POOL_DEVICE="${POOL_DISK}-part${POOL_PART}"

if [[ ${DEBUG} =~ "true" ]]; then
  echo "BOOT_DEVICE: ${BOOT_DEVICE}"
  echo "SWAP_DEVICE: ${SWAP_DEVICE}"
  echo "POOL_DEVICE: ${POOL_DEVICE}"
  echo "DISK: ${DISK}"
  echo "DISKID: ${DISKID}"
  read -rp "Hit enter to continue"
fi

# Swapsize autocalculated to be = Mem size
SWAPSIZE=$(free --giga | grep Mem | awk '{OFS="";print "+", $2 ,"G"}')
export SWAPSIZE

# Start installation
initialize() {
  apt update
  apt install -y debootstrap gdisk zfsutils-linux vim git curl nala
  if [[ ${NALA} =~ "true" ]]; then
    apt install -yq nala
  fi
  zgenhostid -f 0x00bab10c
}

# Disk preparation
disk_prepare() {
  echo "------------> Preparing ${DISK} <------------"
  if [[ ${DEBUG} =~ "true" ]]; then
    echo "BOOT_DEVICE: ${BOOT_DEVICE}"
    echo "SWAP_DEVICE: ${SWAP_DEVICE}"
    echo "POOL_DEVICE: ${POOL_DEVICE}"
    echo "DISK: ${DISK}"
    echo "DISKID: ${DISKID}"
    read -rp "Hit enter to continue"
  fi

  wipefs -a "${DISKID}"
  blkdiscard -f "${DISKID}"
  sgdisk --zap-all "${DISKID}"
  sync
  sleep 2

  sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:EF00" "${BOOT_DISK}"
  sgdisk -n "${SWAP_PART}:0:${SWAPSIZE}" -t "${SWAP_PART}:8200" "${SWAP_DISK}"
  sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:BF00" "${POOL_DISK}"
  sync
  sleep 2
}

# ZFS pool creation
zfs_pool_create() {
  # Create the zpool
  echo "------------> Create zpool <------------"
  echo "${PASSPHRASE}" >/etc/zfs/zroot.key
  chmod 000 /etc/zfs/zroot.key

  zpool create -f -o ashift=12 \
    -O compression=lz4 \
    -O acltype=posixacl \
    -O xattr=sa \
    -O relatime=on \
    -O encryption=aes-256-gcm \
    -O keylocation=file:///etc/zfs/zroot.key \
    -O keyformat=passphrase \
    -o autotrim=on \
    -o compatibility=openzfs-2.1-linux \
    -m none zroot "$POOL_DEVICE"

  sync
  sleep 2

  # Create initial file systems
  zfs create -o mountpoint=none zroot/ROOT
  zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/"${ID}"
  zfs create -o mountpoint=/home zroot/home

  zpool set bootfs=zroot/ROOT/"${ID}" zroot

  # Export, then re-import with a temporary mountpoint of "${MOUNTPOINT}"
  zpool export zroot
  zpool import -N -R "${MOUNTPOINT}" zroot
  ## Remove the need for manual prompt of the passphrase
  echo "${PASSPHRASE}" >/tmp/zpass
  sync
  chmod 0400 /tmp/zpass
  zfs load-key -L file:///tmp/zpass zroot
  rm /tmp/zpass

  zfs mount zroot/ROOT/"${ID}"
  zfs mount zroot/home

  # Update device symlinks
  udevadm trigger
}

# Install Ubuntu
ubuntu_install() {
  echo "------------> Debootstrap Ubuntu ${RELEASE} <------------"
  debootstrap ${RELEASE} "${MOUNTPOINT}"

  # Copy files into the new install
  cp /etc/hostid "${MOUNTPOINT}"/etc/hostid
  cp /etc/resolv.conf "${MOUNTPOINT}"/etc/
  mkdir "${MOUNTPOINT}"/etc/zfs
  cp /etc/zfs/zroot.key "${MOUNTPOINT}"/etc/zfs

  # Chroot into the new OS
  mount -t proc proc "${MOUNTPOINT}"/proc
  mount -t sysfs sys "${MOUNTPOINT}"/sys
  mount -B /dev "${MOUNTPOINT}"/dev
  mount -t devpts pts "${MOUNTPOINT}"/dev/pts

  # Set a hostname
  echo "$HOSTNAME" >"${MOUNTPOINT}"/etc/hostname
  echo "127.0.1.1       $HOSTNAME" >>"${MOUNTPOINT}"/etc/hosts

  # Set root passwd
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  echo -e "root:$PASSWORD" | chpasswd -c SHA256
EOCHROOT

  # Set up APT sources
  cat <<EOF >"${MOUNTPOINT}"/etc/apt/sources.list
# Uncomment the deb-src entries if you need source packages

deb http://archive.ubuntu.com/ubuntu/ ${RELEASE} main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ ${RELEASE} main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ ${RELEASE}-updates main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ ${RELEASE}-updates main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ ${RELEASE}-security main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ ${RELEASE}-security main restricted universe multiverse

deb http://archive.ubuntu.com/ubuntu/ ${RELEASE}-backports main restricted universe multiverse
# deb-src http://archive.ubuntu.com/ubuntu/ ${RELEASE}-backports main restricted universe multiverse
EOF

  # Update the repository cache and system, install base packages, set up
  # console properties
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  if [[ ${NALA} =~ "true" ]]; then
    apt install -yq nala
  fi
  ${APT} update
  ${APT} upgrade -y
  ${APT} install -y --no-install-recommends linux-generic locales keyboard-configuration console-setup curl nala git
EOCHROOT

  chroot "$MOUNTPOINT" /bin/bash -x <<-EOCHROOT
		##4.5 configure basic system
		locale-gen en_US.UTF-8 $LOCALE
		echo 'LANG="$LOCALE"' > /etc/default/locale

		##set timezone
		ln -fs /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
		#dpkg-reconfigure locales tzdata keyboard-configuration console-setup
    dpkg-reconfigure locales keyboard-configuration
EOCHROOT

  # ZFS Configuration
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  ${APT} install -y dosfstools zfs-initramfs zfsutils-linux curl vim wget git
  systemctl enable zfs.target
  systemctl enable zfs-import-cache
  systemctl enable zfs-mount
  systemctl enable zfs-import.target
  echo "UMASK=0077" > /etc/initramfs-tools/conf.d/umask.conf
  update-initramfs -c -k all
EOCHROOT
}

ZBM_install() {
  # Install and configure ZFSBootMenu
  # Set ZFSBootMenu properties on datasets
  # Create a vfat filesystem
  # Create an fstab entry and mount
  echo "------------> Installing ZFSBootMenu <------------"
  cat <<EOF >>${MOUNTPOINT}/etc/fstab
$(blkid | grep "${DISK}${BOOT_PART}" | cut -d ' ' -f 2) /boot/efi vfat defaults 0 0
EOF

  mkdir -p "${MOUNTPOINT}"/boot/efi

  if [[ ${DEBUG} =~ "true" ]]; then
    echo "BOOT_DEVICE: ${BOOT_DEVICE}"
    echo "SWAP_DEVICE: ${SWAP_DEVICE}"
    echo "POOL_DEVICE: ${POOL_DEVICE}"
    echo "DISK: ${DISK}"
    echo "DISKID: ${DISKID}"
    read -rp "Hit enter to continue"
  fi

  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  zfs set org.zfsbootmenu:commandline="quiet loglevel=4" zroot/ROOT
  zfs set org.zfsbootmenu:keysource="zroot/ROOT/${ID}" zroot
  mkfs.vfat -F32 "$BOOT_DEVICE"
EOCHROOT

  # Install ZBM and configure EFI boot entries
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  mount /boot/efi
  mkdir -p /boot/efi/EFI/ZBM
  curl -o /boot/efi/EFI/ZBM/VMLINUZ.EFI -L https://get.zfsbootmenu.org/efi
  cp /boot/efi/EFI/ZBM/VMLINUZ.EFI /boot/efi/EFI/ZBM/VMLINUZ-BACKUP.EFI
  mount -t efivarfs efivarfs /sys/firmware/efi/efivars
EOCHROOT
}

# Create boot entry with efibootmgr
EFI_install() {
  echo "------------> Installing efibootmgr <------------"
  if [[ ${DEBUG} =~ "true" ]]; then
    echo "BOOT_DEVICE: ${BOOT_DEVICE}"
    echo "SWAP_DEVICE: ${SWAP_DEVICE}"
    echo "POOL_DEVICE: ${POOL_DEVICE}"
    echo "DISK: ${DISK}"
    echo "DISKID: ${DISKID}"
    read -rp "Hit enter to continue"
  fi

  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
${APT} install -y efibootmgr
efibootmgr -c -d "$DISK" -p "$BOOT_PART" \
  -L "ZFSBootMenu (Backup)" \
  -l '\EFI\ZBM\VMLINUZ-BACKUP.EFI'

efibootmgr -c -d "$DISK" -p "$BOOT_PART" \
  -L "ZFSBootMenu" \
  -l '\EFI\ZBM\VMLINUZ.EFI'

sync
sleep 1
EOCHROOT

  if [[ ${DEBUG} =~ "true" ]]; then
    read -rp "Finished w/ efibootmgr... waiting."
  fi
}

# Install rEFInd
rEFInd_install() {
  echo "------------> Install rEFInd <-------------"
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  ${APT} install -y curl
  DEBIAN_FRONTEND=noninteractive ${APT} install -y refind
  refind-install
  if [[ -a /boot/refind_linux.conf ]];
  then
    rm /boot/refind_linux.conf
  fi

  #bash -c "$(curl -fsSL https://raw.githubusercontent.com/bobafetthotmail/refind-theme-regular/master/install.sh)"
EOCHROOT

  # Install rEFInd regular theme (Dark)
  cd /root
  ${APT} install -y git
  ${GIT} clone https://github.com/bobafetthotmail/refind-theme-regular.git
  rm -rf refind-theme-regular/{src,.git}
  rm refind-theme-regular/install.sh
  rm -rf "${MOUNTPOINT}"/boot/efi/EFI/refind/{regular-theme,refind-theme-regular}
  rm -rf "${MOUNTPOINT}"/boot/efi/EFI/refind/themes/{regular-theme,refind-theme-regular}
  mkdir -p "${MOUNTPOINT}"/boot/efi/EFI/refind/themes
  sync
  sleep 2
  cp -r refind-theme-regular "${MOUNTPOINT}"/boot/efi/EFI/refind/themes/
  sync
  sleep 2
  cat refind-theme-regular/theme.conf | sed -e '/128/ s/^/#/' \
    -e '/48/ s/^/#/' \
    -e '/ 96/ s/^#//' \
    -e '/ 256/ s/^#//' \
    -e '/256-96.*dark/ s/^#//' \
    -e '/icons_dir.*256/ s/^#//' >"${MOUNTPOINT}"/boot/efi/EFI/refind/themes/refind-theme-regular/theme.conf

  cat <<EOF >>"${MOUNTPOINT}"/boot/efi/EFI/refind/refind.conf
menuentry "Ubuntu (ZBM)" {
    loader /EFI/ZBM/VMLINUZ.EFI
    icon /EFI/refind/themes/refind-theme-regular/icons/256-96/os_ubuntu.png
    options "quit loglevel=0 zbm.skip"
}

menuentry "Ubuntu (ZBM Menu)" {
    loader /EFI/ZBM/VMLINUZ.EFI
    icon /EFI/refind/themes/refind-theme-regular/icons/256-96/os_ubuntu.png
    options "quit loglevel=0 zbm.show"
}

include themes/refind-theme-regular/theme.conf
EOF

  if [[ ${DEBUG} =~ "true" ]]; then
    read -rp "Finished w/ rEFInd... waiting."
  fi
}

# Setup swap partition

create_swap() {
  echo "------------> Create swap partition <------------"

  if [[ ${DEBUG} =~ "true" ]]; then
    echo "BOOT_DEVICE: ${BOOT_DEVICE}"
    echo "SWAP_DEVICE: ${SWAP_DEVICE}"
    echo "POOL_DEVICE: ${POOL_DEVICE}"
    echo "DISK: ${DISK}"
    echo "DISKID: ${DISKID}"
    read -rp "Hit enter to continue"
  fi

  echo swap "${DISKID}"-part2 /dev/urandom \
    swap,cipher=aes-xts-plain64:sha256,size=512 >>"${MOUNTPOINT}"/etc/crypttab
  echo /dev/mapper/swap none swap defaults 0 0 >>"${MOUNTPOINT}"/etc/fstab
}

# Create system groups and network setup
groups_and_networks() {
  echo "------------> Setup groups and networks <----------------"
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  cp /usr/share/systemd/tmp.mount /etc/systemd/system/
  systemctl enable tmp.mount
  addgroup --system lpadmin
  addgroup --system lxd
  addgroup --system sambashare

  echo "network:" >/etc/netplan/01-network-manager-all.yaml
  echo "  version: 2" >>/etc/netplan/01-network-manager-all.yaml
  echo "  renderer: NetworkManager" >>/etc/netplan/01-network-manager-all.yaml
EOCHROOT
}

# Create user
create_user() {
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  adduser --disabled-password --gecos "" ${USERNAME}
  cp -a /etc/skel/. /home/${USERNAME}
  chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}
  usermod -a -G adm,cdrom,dip,lpadmin,lxd,plugdev,sambashare,sudo ${USERNAME}
  echo "diego ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/${USERNAME}
  chown root:root /etc/sudoers.d/${USERNAME}
  chmod 400 /etc/sudoers.d/${USERNAME}
  echo -e "${USERNAME}:$PASSWORD" | chpasswd
EOCHROOT
}

# Install desktop bundle
install_ubuntu_desktop() {
  echo "------------> Installing desktop bundle <------------"
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  ${APT} dist-upgrade -y

    if [[ "$DISTRO" != "server" ]];
		then
			zfs create 	"zroot/ROOT/"${ID}"/var/lib/AccountsService
		fi

		case "$DISTRO" in
			server)	distro_variant
				##Server installation has a command line interface only.
				##Minimal install: ubuntu-server-minimal
				${APT} install --yes ubuntu-server
			;;
			desktop)
				##Ubuntu default desktop install has a full GUI environment.
				##Minimal install: ubuntu-desktop-minimal
				${APT} install --yes ubuntu-desktop
			;;
			kubuntu)
				##Ubuntu KDE plasma desktop install has a full GUI environment.
				##Select sddm as display manager.
				echo sddm shared/default-x-display-manager select sddm | debconf-set-selections
				${APT} install --yes kubuntu-desktop
			;;
			xubuntu)
				##Ubuntu xfce desktop install has a full GUI environment.
				##Select lightdm as display manager.
				echo lightdm shared/default-x-display-manager select lightdm | debconf-set-selections
				${APT} install --yes xubuntu-desktop
			;;
			budgie)
				##Ubuntu budgie desktop install has a full GUI environment.
				##Select lightdm as display manager.
				echo lightdm shared/default-x-display-manager select lightdm | debconf-set-selections
				${APT} install --yes ubuntu-budgie-desktop
			;;
			MATE)
				##Ubuntu MATE desktop install has a full GUI environment.
				##Select lightdm as display manager.
				echo lightdm shared/default-x-display-manager select lightdm | debconf-set-selections
				${APT} install --yes ubuntu-mate-desktop
			;;
      esac
EOCHROOT
}

# Disable log gzipping as we already use compresion at filesystem level
uncompress_logs() {
  echo "------------> Uncompress logs <------------"
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  for file in /etc/logrotate.d/* ; do
    if grep -Eq "(^|[^#y])compress" "${file}" ; then
        sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "${file}"
    fi
EOCHROOT
}

# re-lock root account
disable_root_login() {
  echo "------------> Disable root login <------------"
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  usermod -p '*' root
EOCHROOT
}

#Umount target and final cleanup
cleanup() {
  echo "------------> Final cleanup <------------"
  umount -n -R "${MOUNTPOINT}"
  sync
  sleep 5
  umount -n -R "${MOUNTPOINT}" >/dev/null 2>&1

  zpool export zroot
}

# Download and install RTL8821CE drivers
rtl8821ce_install() {
  echo "------------> Installing RTL8821CE drivers <------------"
  chroot "${MOUNTPOINT}" /bin/bash -x <<-EOCHROOT
  ${APT} install -y bc module-assistant build-essential dkms
  m-a prepare
  cd /root
  ${APT} install -y git
  ${GIT} clone https://github.com/tomaspinho/rtl8821ce.git 
  cd rtl8821ce
  ./dkms-install.sh
  zfs set org.zfsbootmenu:commandline="quiet loglevel=4 splash pcie_aspm=off" zroot/ROOT
  echo "blacklist rtw88_8821ce" >> /etc/modprobe.d/blacklist.conf
EOCHROOT
}

################################################################
# MAIN Program
initialize
disk_prepare
zfs_pool_create
ubuntu_install
create_swap
ZBM_install
EFI_install
rEFInd_install
groups_and_networks
create_user
install_ubuntu_desktop
uncompress_logs
if [[ ${RTL8821CE} =~ "true" ]]; then
  rtl8821ce_install
fi
disable_root_login
cleanup

if [[ ${REBOOT} =~ "true" ]]; then
  reboot
fi
