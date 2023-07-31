## Important
You need to update the variables in from_live_cd.sh to point to the correct
dist and the right amount of RAM so that the swap is set correctly.
``` bash
gsettings set org.gnome.desktop.media-handling automount false

sudo -i

bash from_live_cd.sh

bash from_chroot.sh

bash from_live_cd2.sh

bash first_boot.sh

sudo usermod -p '*' root
```
