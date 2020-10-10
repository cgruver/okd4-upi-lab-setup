#!/bin/bash

set -x

# This script will set up the infrastructure to deploy an OKD 4.X cluster
# Follow the documentation at https://github.com/cgruver/okd4-UPI-Lab-Setup
NIGHTLY=false
IP_CONFIG_1=""
IP_CONFIG_2=""
IP_CONFIG=""
LB_IP_LIST=""
CLUSTER_NAME="okd4"
LAB_PWD=$(cat ${OKD4_LAB_PATH}/lab_guest_pw)

for i in "$@"
do
case $i in
    -i=*|--inventory=*)
    INVENTORY="${i#*=}"
    shift # past argument=value
    ;;
    -url=*|--install-url=*)
    INSTALL_URL="${i#*=}"
    shift
    ;;
    -gw=*|--gateway=*)
    LAB_GATEWAY="${i#*=}"
    shift # past argument with no value
    ;;
    -nm=*|--netmask=*)
    LAB_NETMASK="${i#*=}"
    shift # past argument with no value
    ;;
    -d=*|--domain=*)
    LAB_DOMAIN="${i#*=}"
    shift # past argument with no value
    ;;
    -dns=*|--nameserver=*)
    LAB_NAMESERVER="${i#*=}"
    shift # past argument with no value
    ;;
    -cn=*|--name=*)
    CLUSTER_NAME="${i#*=}"
    shift
    ;;
    -n|--nightly)
    NIGHTLY=true
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done

function configOkdNode() {
    
  local ip_addr=${1}
  local host_name=${2}
  local mac=${3}
  local role=${4}

cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/${mac//:/-}.yml
variant: fcos
version: 1.1.0
ignition:
  config:
    merge:
      - local: ${role}.ign
storage:
  files:
    - path: /etc/zincati/config.d/90-disable-feature.toml
      mode: 0644
      contents:
        inline: |
          [updates]
          enabled = false
    - path: /etc/systemd/network/25-nic0.link
      mode: 0644
      contents:
        inline: |
          [Match]
          MACAddress=${mac}
          [Link]
          Name=nic0
    - path: /etc/NetworkManager/system-connections/nic0.nmconnection
      mode: 0600
      overwrite: true
      contents:
        inline: |
          [connection]
          type=ethernet
          interface-name=nic0

          [ethernet]
          mac-address=${mac}

          [ipv4]
          method=manual
          addresses=${ip_addr}/${LAB_NETMASK}
          gateway=${LAB_GATEWAY}
          dns=${LAB_NAMESERVER}
          dns-search=${LAB_DOMAIN}
    - path: /etc/hostname
      mode: 0420
      overwrite: true
      contents:
        inline: |
          ${host_name}
EOF

cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/${mac//:/-}.ipxe
#!ipxe

kernel ${INSTALL_URL}/fcos/vmlinuz edd=off net.ifnames=1 rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=${INSTALL_URL}/fcos/install.xz coreos.inst.ignition_url=${INSTALL_URL}/fcos/ignition/${CLUSTER_NAME}/${mac//:/-}.ign coreos.inst.platform_id=qemu console=ttyS0
initrd ${INSTALL_URL}/fcos/initrd
initrd ${INSTALL_URL}/fcos/rootfs.img

boot
EOF

}

function createLbHostList() {

  local port=${1}
  local host_name=""
  local role=""
  local vars=""
  local node_ip=""
  
  rm -f ${OKD4_LAB_PATH}/ipxe-work-dir/tmpFile
  # Get the list of master & bootstrap IPs for the HA Proxy configuration
  for vars in $(cat ${INVENTORY} | grep -v "#" | grep -v "HA-PROXY")
  do
    host_name=$(echo ${vars} | cut -d',' -f2)
    role=$(echo ${vars} | cut -d',' -f8)
    if [[ ${role} == "bootstrap" ]] || [[ ${role} == "master" ]]
    then
      node_ip=$(dig ${host_name}.${LAB_DOMAIN} +short)
      echo "    server ${host_name} ${node_ip}:${port} check weight 1" >> ${OKD4_LAB_PATH}/ipxe-work-dir/tmpFile
    fi
  done

}

function configLbNode() {

  local ip_addr=${1}
  local host_name=${2}
  local mac=${3}

# Create the iPXE boot file for this host
cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/${mac//:/-}.ipxe
#!ipxe

kernel ${INSTALL_URL}/centos/isolinux/vmlinuz edd=off net.ifnames=1 ifname=nic0:${mac} ip=${ip_addr}::${LAB_GATEWAY}:${LAB_NETMASK}:${host_name}.${LAB_DOMAIN}:nic0:none nameserver=${LAB_NAMESERVER} inst.ks=${INSTALL_URL}/kickstart/${mac//:/-}.ks inst.repo=${INSTALL_URL}/centos initrd=initrd.img console=ttyS0
initrd ${INSTALL_URL}/centos/isolinux/initrd.img

boot
EOF

# Create the Kickstart file
cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/${mac//:/-}.ks
#version=RHEL8
cmdline
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
repo --name="Minimal" --baseurl=${INSTALL_URL}/centos/Minimal
url --url="${INSTALL_URL}/centos"
rootpw --iscrypted ${LAB_PWD}
firstboot --disable
skipx
services --enabled="chronyd"
timezone America/New_York --isUtc

# Disk partitioning information
ignoredisk --only-use=sda
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
clearpart --drives=sda --all --initlabel
zerombr
part /boot --fstype="xfs" --ondisk=sda --size=1024
part /boot/efi --fstype="efi" --ondisk=sda --size=600 --fsoptions="umask=0077,shortname=winnt"
part pv.1 --fstype="lvmpv" --ondisk=sda --size=1024 --grow --maxsize=2000000
volgroup centos --pesize=4096 pv.1
logvol swap  --fstype="swap" --size=16064 --name=swap --vgname=centos
logvol /  --fstype="xfs" --grow --maxsize=2000000 --size=1024 --name=root --vgname=centos

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
set -x
dnf -y install yum-utils
yum-config-manager --disable AppStream
yum-config-manager --disable BaseOS
yum-config-manager --disable extras
yum-config-manager --add-repo ${INSTALL_URL}/postinstall/local-repos.repo

mkdir -p /root/.ssh
chmod 700 /root/.ssh
curl -o /root/.ssh/authorized_keys ${INSTALL_URL}/postinstall/authorized_keys
chmod 600 /root/.ssh/authorized_keys

dnf -y install net-tools bind-utils bash-completion kexec-tools haproxy policycoreutils-python-utils
dnf -y update
curl -o /etc/haproxy/haproxy.cfg ${INSTALL_URL}/postinstall/haproxy.${host_name}.cfg
curl -o /etc/chrony.conf ${INSTALL_URL}/postinstall/chrony.conf

firewall-offline-cmd --add-port=80/tcp 
firewall-offline-cmd --add-port=8080/tcp 
firewall-offline-cmd --add-port=443/tcp 
firewall-offline-cmd --add-port=6443/tcp 
firewall-offline-cmd --add-port=22623/tcp 

curl -o /root/firstboot.sh ${INSTALL_URL}/firstboot/haproxy.${host_name}.fb
chmod 750 /root/firstboot.sh
echo "@reboot root /bin/bash /root/firstboot.sh" >> /etc/crontab

%end

reboot
EOF

# Create the firstboot script

cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/haproxy.${host_name}.fb

setenforce 0
systemctl enable haproxy --now
grep haproxy /var/log/audit/audit.log | audit2allow -M haproxy
semodule -i haproxy.pp
setenforce 1
/bin/cat /etc/crontab | /bin/grep -v firstboot > /etc/crontab.tmp
/bin/rm -f /etc/crontab
/bin/mv /etc/crontab.tmp /etc/crontab
rm -f \$0

EOF

# Create the haproxy.cfg file

  createLbHostList 6443
  API_LIST=$(cat ${OKD4_LAB_PATH}/ipxe-work-dir/tmpFile)
  createLbHostList 22623
  MC_LIST=$(cat ${OKD4_LAB_PATH}/ipxe-work-dir/tmpFile)
  createLbHostList 80
  APPS_LIST=$(cat ${OKD4_LAB_PATH}/ipxe-work-dir/tmpFile | grep -v bootstrap)
  createLbHostList 443
  APPS_SSL_LIST=$(cat ${OKD4_LAB_PATH}/ipxe-work-dir/tmpFile | grep -v bootstrap)

cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/haproxy.${host_name}.cfg
global

    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     50000
    user        haproxy
    group       haproxy
    daemon

    stats socket /var/lib/haproxy/stats

defaults
    mode                    http
    log                     global
    option                  dontlognull
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          10m
    timeout server          10m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 50000

listen okd4-api 
    bind 0.0.0.0:6443
    balance roundrobin
    option                  tcplog
    mode tcp
    option tcpka
    option tcp-check
${API_LIST}

listen okd4-mc 
    bind 0.0.0.0:22623
    balance roundrobin
    option                  tcplog
    mode tcp
    option tcpka
${MC_LIST}

listen okd4-apps 
    bind 0.0.0.0:80
    balance source
    option                  tcplog
    mode tcp
    option tcpka
${APPS_LIST}

listen okd4-apps-ssl 
    bind 0.0.0.0:443
    balance source
    option                  tcplog
    mode tcp
    option tcpka
    option tcp-check
${APPS_SSL_LIST}
EOF

  scp ${OKD4_LAB_PATH}/ipxe-work-dir/${mac//:/-}.ks root@${INSTALL_HOST}:${INSTALL_ROOT}/kickstart/${mac//:/-}.ks
  scp ${OKD4_LAB_PATH}/ipxe-work-dir/haproxy.${host_name}.fb root@${INSTALL_HOST}:${INSTALL_ROOT}/firstboot/haproxy.${host_name}.fb
  scp ${OKD4_LAB_PATH}/ipxe-work-dir/haproxy.${host_name}.cfg root@${INSTALL_HOST}:${INSTALL_ROOT}/postinstall/haproxy.${host_name}.cfg

}

# Create and deploy ignition files
rm -rf ${OKD4_LAB_PATH}/okd4-install-dir
mkdir ${OKD4_LAB_PATH}/okd4-install-dir
mkdir -p ${OKD4_LAB_PATH}/ipxe-work-dir/ignition
cp ${OKD4_LAB_PATH}/install-config-upi.yaml ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
if [[ ${NIGHTLY} == "true" ]]
then
  OKD_PREFIX=$(echo ${OKD_RELEASE} | cut -d"." -f1,2)
  OKD_VER=$(echo ${OKD_RELEASE} | sed  "s|${OKD_PREFIX}.0-0.okd|${OKD_PREFIX}|g")
  sed -i "s|%%OKD_SOURCE_1%%|registry.svc.ci.openshift.org/origin/${OKD_VER}|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
  sed -i "s|%%OKD_SOURCE_2%%|registry.svc.ci.openshift.org/origin/release|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
else
  sed -i "s|%%OKD_SOURCE_1%%|quay.io/openshift/okd|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
  sed -i "s|%%OKD_SOURCE_2%%|quay.io/openshift/okd-content|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
fi
sed -i "s|%%CLUSTER_NAME%%|${CLUSTER_NAME}|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir create ignition-configs

# Create Virtual Machines from the inventory file
for VARS in $(cat ${INVENTORY} | grep -v "#")
do
  HOST_NODE=$(echo ${VARS} | cut -d',' -f1)
  HOSTNAME=$(echo ${VARS} | cut -d',' -f2)
  MEMORY=$(echo ${VARS} | cut -d',' -f3)
  CPU=$(echo ${VARS} | cut -d',' -f4)
  ROOT_VOL=$(echo ${VARS} | cut -d',' -f5)
  DATA_VOL=$(echo ${VARS} | cut -d',' -f6)
  NICS=$(echo ${VARS} | cut -d',' -f7)
  ROLE=$(echo ${VARS} | cut -d',' -f8)
  VBMC_PORT=$(echo ${VARS} | cut -d',' -f9)

  DISK_LIST="--disk size=${ROOT_VOL},path=/VirtualMachines/${HOSTNAME}/rootvol,bus=sata"
  if [ ${DATA_VOL} != "0" ]
  then
    DISK_LIST="${DISK_LIST} --disk size=${DATA_VOL},path=/VirtualMachines/${HOSTNAME}/datavol,bus=sata"
  fi
  ARGS="--cpu host-passthrough,match=exact"

  # Get IP address for eth0
  IP_01=$(dig ${HOSTNAME}.${LAB_DOMAIN} +short)
  NET_DEVICE="--network bridge=br0"

  if [[ ${NICS} == "2" ]]
  then
    NET_DEVICE="--network bridge=br0 --network bridge=br1"
    # IP address for eth1 is the same as eth0 with the third octet incremented by 1.  i.e. eth0=10.11.11.10, eth1=10.11.12.10
    let O_1=$(echo ${IP_01} | cut -d'.' -f1)
    let O_2=$(echo ${IP_01} | cut -d'.' -f2)
    let O_3=$(echo ${IP_01} | cut -d'.' -f3)
    let O_4=$(echo ${IP_01} | cut -d'.' -f4)
    let O_3=${O_3}+1
    IP_02="${O_1}.${O_2}.${O_3}.${O_4}"
  fi

  # Create the VM
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "mkdir -p /VirtualMachines/${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virt-install --print-xml 1 --name ${HOSTNAME} --memory ${MEMORY} --vcpus ${CPU} --boot=hd,network,menu=on,useserial=on ${DISK_LIST} ${NET_DEVICE} --graphics none --noautoconsole --os-variant centos7.0 ${ARGS} > /VirtualMachines/${HOSTNAME}.xml"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh define /VirtualMachines/${HOSTNAME}.xml"

  # Get the MAC address for eth0 in the new VM  
  var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
  NET_MAC_0=$(echo ${var} | cut -d" " -f5)

  if [[ ${ROLE} != "ha-proxy" ]]
  then
    # Create node specific files
    configOkdNode ${IP_01} ${HOSTNAME}.${LAB_DOMAIN} ${NET_MAC_0} ${ROLE}
    cat ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/${NET_MAC_0//:/-}.yml | fcct -d ${OKD4_LAB_PATH}/okd4-install-dir/ -o ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/${NET_MAC_0//:/-}.ign
  else
    # Create the HA Proxy LB Server
    configLbNode ${IP_01} ${HOSTNAME}.${LAB_DOMAIN} ${NET_MAC_0}
  fi
  # Create a virtualBMC instance for this VM
  vbmc add --username admin --password password --port ${VBMC_PORT} --address ${BASTION_HOST} --libvirt-uri qemu+ssh://root@${HOST_NODE}.${LAB_DOMAIN}/system ${HOSTNAME}
  vbmc start ${HOSTNAME}
done

ssh root@${INSTALL_HOST} "mkdir -p ${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}"
scp -r ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/*.ign root@${INSTALL_HOST}:${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}/
ssh root@${INSTALL_HOST} "chmod 644 ${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}/*"
scp -r ${OKD4_LAB_PATH}/ipxe-work-dir/*.ipxe root@${PXE_HOST}:/data/tftpboot/ipxe/

# Clean up
rm -rf ${OKD4_LAB_PATH}/ipxe-work-dir
