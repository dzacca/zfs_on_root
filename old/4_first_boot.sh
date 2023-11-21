#!\bin\bash
#
username=diego

UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null |
    tr -dc 'a-z0-9' | cut -c-6)
ROOT_DS=$(zfs list -o name | awk '/ROOT\/ubuntu_/{print $1;exit}')
zfs create -o com.ubuntu.zsys:bootfs-datasets=$ROOT_DS \
    -o canmount=on -o mountpoint=/home/$username \
    rpool/USERDATA/${username}_$UUID
adduser $username

cp -a /etc/skel/. /home/$username
chown -R $username:$username /home/$username
usermod -a -G adm,cdrom,dip,lpadmin,lxd,plugdev,sambashare,sudo $username

apt dist-upgrade --yes

apt install --yes ubuntu-desktop

rm /etc/netplan/01-netcfg.yaml

echo "network:" >/etc/netplan/01-network-manager-all.yaml
echo "  version: 2" >>/etc/netplan/01-network-manager-all.yaml
echo "  renderer: NetworkManager" >>/etc/netplan/01-network-manager-all.yaml

for file in /etc/logrotate.d/* ; do
    if grep -Eq "(^|[^#y])compress" "$file" ; then
        sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
    fi
done
