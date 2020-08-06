#!/bin/bash

DISK_1=""
DISK_2=""

for i in "$@"
do
case $i in
    -h=*|--hostname=*)
    HOSTNAME="${i#*=}"
    shift
    ;;
    -m=*|--mac=*)
    NET_MAC="${i#*=}"
    shift
    ;;
    -d=*|--diskList=*)
    DISK="${i#*=}"
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done

DISK_1=$(echo ${DISK} | cut -d"," -f 1)
DISK_2=$(echo ${DISK} | cut -d"," -f 2)
if [[ ${DISK_1} == ${DISK_2} ]]
then
  DISK_2=""
fi

LAB_PWD=$(cat ${OKD4_LAB_PATH}/lab_pwd)

function createPartInfo() {

if [[ ${DISK_2} == "" ]]
then
cat <<EOF
part pv.1 --fstype="lvmpv" --ondisk=${DISK_1} --size=1024 --grow --maxsize=2000000
volgroup centos --pesize=4096 pv.1
EOF
else
cat <<EOF
part pv.1 --fstype="lvmpv" --ondisk=${DISK_1} --size=1024 --grow --maxsize=2000000
part pv.2 --fstype="lvmpv" --ondisk=${DISK_2} --size=1024 --grow --maxsize=2000000
volgroup centos --pesize=4096 pv.1 pv.2
EOF
fi
}

# Create temporary work directory
mkdir -p ${OKD4_LAB_PATH}/ipxe-work-dir

# Get IP address for nic0
IP=$(dig ${HOSTNAME}.${LAB_DOMAIN} +short)

# Create and deploy the iPXE boot file for this host
cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
#!ipxe

kernel ${INSTALL_URL}/centos/isolinux/vmlinuz net.ifnames=1 ifname=nic0:${NET_MAC} ip=${IP}::${LAB_GATEWAY}:${LAB_NETMASK}:${HOSTNAME}.${LAB_DOMAIN}:nic0:none nameserver=${LAB_NAMESERVER} inst.ks=${INSTALL_URL}/kickstart/${NET_MAC//:/-}.ks inst.repo=${INSTALL_URL}/centos initrd=initrd.img
initrd ${INSTALL_URL}/centos/isolinux/initrd.img

boot
EOF

scp ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe root@${PXE_HOST}:/var/lib/tftpboot/ipxe/${NET_MAC//:/-}.ipxe

# Create the Kickstart file

PART_INFO=$(createPartInfo)

cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ks
#version=RHEL8
cmdline
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
repo --name="Minimal" --baseurl=${INSTALL_URL}/centos-8/Minimal
url --url="${INSTALL_URL}/centos-8"
rootpw --iscrypted ${LAB_PWD}
firstboot --disable
skipx
services --enabled="chronyd"
timezone America/New_York --isUtc

# Disk partitioning information
ignoredisk --only-use=${DISK}
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=${DISK_1}
clearpart --drives=${DISK} --all --initlabel
zerombr
part /boot --fstype="xfs" --ondisk=${DISK_1} --size=1024
part /boot/efi --fstype="efi" --ondisk=${DISK_1} --size=600 --fsoptions="umask=0077,shortname=winnt"
${PART_INFO}
logvol swap  --fstype="swap" --size=16064 --name=swap --vgname=centos
logvol /  --fstype="xfs" --grow --maxsize=2000000 --size=1024 --name=root --vgname=centos

# Network Config
network  --hostname=${HOSTNAME}
network  --device=nic0 --noipv4 --noipv6 --no-activate --onboot=no
network  --bootproto=static --device=br0 --bridgeslaves=nic0 --gateway=${LAB_GATEWAY} --ip=${IP} --nameserver=${LAB_NAMESERVER} --netmask=${LAB_NETMASK} --noipv6 --activate --bridgeopts="stp=false" --onboot=yes

eula --agreed

%packages
@^minimal-environment
kexec-tools
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

%post
dnf -y install yum-utils
yum-config-manager --disable base
yum-config-manager --disable updates
yum-config-manager --disable extras
yum-config-manager --add-repo ${INSTALL_URL}/postinstall/local-repos.repo

mkdir -p /root/.ssh
chmod 700 /root/.ssh
curl -o /root/.ssh/authorized_keys ${INSTALL_URL}/postinstall/authorized_keys
chmod 600 /root/.ssh/authorized_keys
dnf -y module install virt
dnf -y install wget git net-tools bind-utils bash-completion nfs-utils rsync libvirt-python libguestfs-tools virt-install iscsi-initiator-utils
dnf -y update
echo "InitiatorName=iqn.$(hostname)" > /etc/iscsi/initiatorname.iscsi
echo "options kvm_intel nested=1" >> /etc/modprobe.d/kvm.conf
systemctl enable libvirtd --now
mkdir /VirtualMachines
virsh pool-destroy default
virsh pool-undefine default
virsh pool-define-as --name default --type dir --target /VirtualMachines
virsh pool-autostart default
virsh pool-start default
mkdir -p /root/bin
curl -o /root/bin/rebuildhost.sh ${INSTALL_URL}/postinstall/rebuildhost.sh
chmod 700 /root/bin/rebuildhost.sh
curl -o /etc/chrony.conf ${INSTALL_URL}/postinstall/chrony.conf
%end

reboot

EOF

scp ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ks root@${INSTALL_HOST}:${INSTALL_ROOT}/kickstart/${NET_MAC//:/-}.ks

# Clean up
rm -rf ${OKD4_LAB_PATH}/ipxe-work-dir
