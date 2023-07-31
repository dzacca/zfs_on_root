## Important
You need to update the variables in from_live_cd.sh to point to the correct
dist and the right amount of RAM so that the swap is set correctly.

sudo apt update

gsettings set org.gnome.desktop.media-handling automount false

sudo -i

from_live_cd.sh
from_chroot1.sh

vi /etc/default/grub
# Add init_on_alloc=0 to: GRUB_CMDLINE_LINUX_DEFAULT
# Save and quit (or see the next step).

vi /etc/default/grub
# Comment out: GRUB_TIMEOUT_STYLE=hidden
# Set: GRUB_TIMEOUT=5
# Below GRUB_TIMEOUT, add: GRUB_RECORDFAIL_TIMEOUT=5
# Remove quiet and splash from: GRUB_CMDLINE_LINUX_DEFAULT
# Uncomment: GRUB_TERMINAL=console
# Save and quit.


from_chroot2.sh
from_live_cd2.sh
first_boot.sh

sudo usermod -p '*' root
