# ZFS_ON_ROOT
## for Ubuntu 23.04
This is a very basic set of scripts that I created to make it quicker for me
to do set up VMs or play around with ZFS-based installation of Ubuntu.
The scripts are based on the documentation from
[OpenZFS](https://openzfs.github.io/openzfs-docs/Getting%20Started/Ubuntu/Ubuntu%2022.04%20Root%20on%20ZFS.html#step-5-grub-installation),
single disk, with rpool encrypted with native ZFS encryption, and no ZSys
installation (I don't use ZSys and it will be deprecated in any case).

These are not meant for production use, there's no documentation at this stage
and I don't know if and how I will evolve them. Feel free to provide feedback,
open issues, or send pull requests. I don't have much time to polish things up
se this repository is likely to stay in a MVP stage pretty much forever.


### Important
You need to update the variables in `from_live_cd.sh` to point to the correct
disk and the right amount of RAM so that the swap is set correctly.

``` bash
gsettings set org.gnome.desktop.media-handling automount false
sudo apt update && sudo apt install -y git vim

sudo -i
git clone https://github.com/dzacca/zfs_on_root.git
cd zfs_on_root

bash from_live_cd.sh

bash from_chroot.sh

bash from_live_cd2.sh

bash first_boot.sh

sudo usermod -p '*' root
```
