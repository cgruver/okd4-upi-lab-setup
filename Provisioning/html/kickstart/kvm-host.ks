auth --enableshadow --passalgo=sha512
%include /tmp/net-info
install
url --url=%%INSTALL_URL%%/centos/
text
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
rootpw --iscrypted %%LAB_PWD%%
services --enabled="chronyd"
timezone America/New_York --isUtc
%include /tmp/part-info

%packages
@^minimal
@core
chrony
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

eula --agreed

%pre
for i in $(ls /sys/class/net)
do
  if [ $(cat /sys/class/net/${i}/operstate) == "up" ]
  then
    NET_IF=${i}
  fi
done
j=$(cat /sys/class/net/${NET_IF}/address)
NET_MAC=${j//:}
curl -o /tmp/net-vars %%INSTALL_URL%%/hostconfig/${NET_MAC}
source /tmp/net-vars
cat << EOF > /tmp/net-info
network  --device=${NET_IF} --noipv4 --noipv6 --no-activate --onboot=no
network  --bootproto=static --device=br0 --bridgeslaves=${NET_IF} --gateway=${GATEWAY} --ip=${IP} --nameserver=${NAME_SERVER} --netmask=${NETMASK} --noipv6 --activate --bridgeopts="stp=false" --onboot=yes
network  --hostname=${HOST_NAME}
EOF

if [ -d /sys/block/sdb ]
then

# 2-drive part-info
cat << EOF > /tmp/part-info
ignoredisk --only-use=sda,sdb
clearpart --drives=sda,sdb --all --initlabel
zerombr
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
part /boot --fstype="xfs" --ondisk=sda --size=1024
part /boot/efi --fstype="efi" --ondisk=sda --size=200 --fsoptions="umask=0077,shortname=winnt"
part pv.1 --fstype="lvmpv" --ondisk=sda --size=1024 --grow --maxsize=2000000
part pv.2 --fstype="lvmpv" --ondisk=sdb --size=1024 --grow --maxsize=2000000
volgroup centos --pesize=4096 pv.1 pv.2
logvol swap  --fstype="swap" --size=16064 --name=swap --vgname=centos
logvol /  --fstype="xfs" --grow --maxsize=2000000 --size=1024 --name=root --vgname=centos
EOF

else

# 1-drive part-info
cat << EOF > /tmp/part-info
ignoredisk --only-use=sda
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
clearpart --all 
zerombr
part /boot --fstype="xfs" --ondisk=sda --size=1024
part /boot/efi --fstype="efi" --ondisk=sda --size=200 --fsoptions="umask=0077,shortname=winnt"
part pv.1 --fstype="lvmpv" --ondisk=sda --size=1024 --grow --maxsize=2000000
volgroup centos --pesize=4096 pv.1
logvol swap  --fstype="swap" --size=16064 --name=swap --vgname=centos
logvol /  --fstype="xfs" --grow --maxsize=2000000 --size=1024 --name=root --vgname=centos
EOF

fi

%end

%post
yum -y install yum-utils
yum-config-manager --disable base
yum-config-manager --disable updates
yum-config-manager --disable extras
yum-config-manager --add-repo %%INSTALL_URL%%/postinstall/local-repos.repo

curl -o /root/firstboot.sh %%INSTALL_URL%%/firstboot/kvm-host.fb
chmod 750 /root/firstboot.sh
echo "@reboot root /bin/bash /root/firstboot.sh" >> /etc/crontab
mv /etc/sysconfig/selinux /root/selinux
cat <<EOF > /etc/sysconfig/selinux
SELINUX=disabled
SELINUXTYPE=targeted
EOF

%end

reboot
