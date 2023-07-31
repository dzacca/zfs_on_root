## Important
You need to update the variables in from_live_cd.sh to point to the correct
dist and the right amount of RAM so that the swap is set correctly.

sudo apt update

gsettings set org.gnome.desktop.media-handling automount false

sudo -i

from_live_cd.sh
from_chroot.sh
from_live_cd2.sh
first_boot.sh

sudo usermod -p '*' root
