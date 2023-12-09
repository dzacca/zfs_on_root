# ZFS_ON_ROOT

## CURRENTLY BROKEN - DO NOT USE

## for Ubuntu 23.04 and higher

This is a very basic script that I created to make it quicker for me
to set up VMs or play around with ZFS-based installation of Ubuntu.
The script is based on the documentation from
[OpenZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2022.04%20Root%20on%20ZFS.html#step-5-grub-installation), [ZFSBootMenu](https://docs.zfsbootmenu.org/en/v2.2.x/index.html), and with some ideas taken from  [ubuntu-server-zfsbootmenu](https://github.hscsec.cn/Sithuk/ubuntu-server-zfsbootmenu).
The script currently install Ubuntu on a single disk, with zpool encrypted with native ZFS encryption, and no ZSys installation (I don't use ZSys and it will be deprecated in any case). The layout of the partition is a modified version of what used by ZFSBootMenu as I create the following:

- Partition 1: EFI
- Partition 2: Swap (size is automatically calculated by the script and it's set at the same size of the amount of memory you have)
- Partition 3: zroot

The script is still work in progress and is not yet meant for production use.
There's no documentation at this stage, although the script is pretty much self-explanatory.

Feel free to provide feedback, open issues, or send pull requests.

### Important

You need to update the variables in `zfs_on_root_zbm.sh` to point to the correct
disk and setup the initial variables.

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
########################
# Change ${RUN} to true to execute the script
RUN="false"

# Variables - Populate/tweak this before launching the script
export RELEASE="mantic"
export DISK="/dev/disk/by-id/"
export PASSPHRASE="SomeRandomKey"
export PASSWORD="mypassword"
export HOSTNAME="myhost"
export USERNAME="myuser"

## Auto-reboot at the end of installation? (true/false)
REBOOT="false" 
DEBUG="false"
```

as root, execute the script `./zfs_on_root_zbm.sh`

I adedd an option to download and install rl8821ce drivers as the 
ones shipped with ubuntu always gives me headhaches.

### To Do

- add options for more customisation
