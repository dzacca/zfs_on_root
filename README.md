# ZFS_ON_ROOT

## for Ubuntu 23.04 and higher

This is a very basic script that I created to make it quicker for me to set up VMs or play around with ZFS-based installation of Ubuntu.
The script will set up a system using [ZFSBootMenu](https://docs.zfsbootmenu.org/en/v2.2.x/index.html)(ZBM) and [rEFInd](https://www.rodsbooks.com/refind/).
EFI entries are created directly wich efibootmgr for ZBM **and** for rEFInd. Why? Purely to have a backup in case something goes wrong.

Why ZBM? Because I had enough of random issues with GRUB and ZFS. ZBM just works and integrates a number of ZFS dedicated functionalities that makes my life easier.
Why rEFInd? Now, this is not technically needed, but it's simple to use, tweak, and maintain and works like a charm in dual/multi-boot environments.

The script is based on the documentation from
[OpenZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2022.04%20Root%20on%20ZFS.html#step-5-grub-installation), [ZFSBootMenu](https://docs.zfsbootmenu.org/en/v2.2.x/index.html), and with some ideas taken from  [ubuntu-server-zfsbootmenu](https://github.hscsec.cn/Sithuk/ubuntu-server-zfsbootmenu).
The script currently install Ubuntu on a single disk, with zpool encrypted with native ZFS encryption, and no ZSys installation (I don't use ZSys and it will be deprecated in any case). The layout of the partitions is a modified version of what used by ZFSBootMenu as I create the following:

- Partition 1: EFI
- Partition 2: Swap (size is automatically calculated by the script and it's set at the same size of the amount of memory you have)
- Partition 3: zroot

The script uses the ZFS layout recommended by ZBM

Starting from version 1.0.16 the script has been production-tested on various brands of laptops and desktops machines with no reported issue.
There's little to no documentation at this stage, although the script is pretty much self-explanatory.

Feel free to provide feedback, open issues, or send pull requests.

### Important

You need to update the variables in `zfs_on_root_zbm.sh` to point to the correct
disk and setup the initial variables to define the behaviour of the script.

If your machine uses RTL8821CE as a wifi chipset you are 99% guaranteed to face connectivity issues bad enough to impact the stability of your 
system, even during the installation. Set the relevant variable to "true" and the script will download, compile, and install the working drivers.
If you are in this situation **connect your machine to the network with a physical cable and avoid wifi during the installation**.

### Usage

```bash
gsettings set org.gnome.desktop.media-handling automount false
sudo -i 
```

```bash
cd
apt update && sudo apt install -y git vim
git clone https://github.com/dzacca/zfs_on_root.git
cd zfs_on_root
vi zfs_on_root_zbm.sh
```

Edit the variables at the beginning of the file and make sure to change RUN to true, or the script will exit without doing anything.

```shell
# Change ${RUN} to true to execute the script
RUN="false"

# Variables - Populate/tweak this before launching the script
export DISTRO="desktop"           #server, desktop
export RELEASE="mantic"           # The short name of the release as it appears in the repository (mantic, jammy, etc)
export DISK="sda"                 # Enter the disk name only (sda, sdb, nvme1, etc)
export PASSPHRASE="SomeRandomKey" # Encryption passphrase for "${POOLNAME}"
export PASSWORD="mypassword"      # temporary root password & password for ${USERNAME}
export HOSTNAME="myhost"          # hostname of the new machine
export USERNAME="myuser"          # user to create in the new machine
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
POOLNAME="zroot" #"${POOLNAME}" is the default name used in the HOW TO from ZFSBootMenu. You can change it to
                 # whateven you want but I discourage it.
```

as root, execute the script `./zfs_on_root_zbm.sh`

I adedd an option to download and install rl8821ce drivers as the 
ones shipped with ubuntu always gives me headhaches.

#### Important - EFI Default entry 
If at the end of the installation, when you reboot, rEFInd doesn't show up, it's likely that your BIOS is pointing to another EFI entry.
Enter the machine set-up menu at boot time and change the boot order to use rEFInd as the default one.

### To Do

- add options for more customisation

### Contributors
- https://github.com/VVSShh
