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
j=$(cat /sys/class/net/eno1/address)
NET_MAC=${j//:/-}
curl -o /tmp/install-vars %%INSTALL_URL%%/hostconfig/${NET_MAC}
source /tmp/install-vars

cat << EOF > /tmp/net-info
network  --hostname=${HOST_NAME}
network  --device=eno1 --noipv4 --noipv6 --no-activate --onboot=no
network  --bootproto=static --device=br0 --bridgeslaves=eno1 --gateway=${GATEWAY_01} --ip=${IP_01} --nameserver=${NAME_SERVER} --netmask=${NETMASK_01} --noipv6 --activate --bridgeopts="stp=false" --onboot=yes
EOF

if [ ${NIC_02} != "" ]
then
cat << EOF >> /tmp/net-info
network  --device=${NIC_02} --noipv4 --noipv6 --no-activate --onboot=no
network  --bootproto=static --device=br1 --bridgeslaves=${NIC_02} --ip=${IP_02} --netmask=${NETMASK_02} --noipv6 --activate --bridgeopts="stp=false" --onboot=yes
EOF
fi

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

curl -o /root/firstboot.sh %%INSTALL_URL%%/firstboot/lab-host.fb
chmod 750 /root/firstboot.sh
echo "@reboot root /bin/bash /root/firstboot.sh" >> /etc/crontab
mv /etc/sysconfig/selinux /root/selinux
cat <<EOF > /etc/sysconfig/selinux
SELINUX=disabled
SELINUXTYPE=targeted
EOF

%end

reboot
