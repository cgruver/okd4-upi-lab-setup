#!/bin/bash

set -x

# This script will set up the infrastructure to deploy an OKD 4.X cluster
# Follow the documentation at https://github.com/cgruver/okd4-UPI-Lab-Setup
PULL_RELEASE=false
USE_MIRROR=false
IP_CONFIG_1=""
IP_CONFIG_2=""
IP_CONFIG=""
CLUSTER_NAME="okd4"

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
    -n=*|--name=*)
    CLUSTER_NAME="${i#*=}"
    shift
    ;;
    -m|--mirror)
    USE_MIRROR=true
    shift
    ;;
    -p|--pull-release)
    PULL_RELEASE=true
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done

function configIgnition() {
    
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
      - local: ${OKD4_LAB_PATH}/okd4-install-dir/${role}.ign
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
}

function configIpxe() {

  local mac=${1}

cat << EOF > ${OKD4_LAB_PATH}/ipxe-work-dir/${mac//:/-}.ipxe
#!ipxe

kernel ${INSTALL_URL}/fcos/vmlinuz net.ifnames=1 rd.neednet=1 coreos.inst=yes coreos.inst.install_dev=sda coreos.inst.image_url=${INSTALL_URL}/fcos/install.xz coreos.inst.ignition_url=${INSTALL_URL}/fcos/ignition/${CLUSTER_NAME}/${mac//:/-}.ign coreos.inst.platform_id=qemu console=ttyS0
initrd ${INSTALL_URL}/fcos/initrd

boot
EOF
}

# Retreive fcct
mkdir -p ${OKD4_LAB_PATH}/ipxe-work-dir/ignition
wget https://github.com/coreos/fcct/releases/download/v0.6.0/fcct-x86_64-unknown-linux-gnu
mv fcct-x86_64-unknown-linux-gnu ${OKD4_LAB_PATH}/ipxe-work-dir/fcct 
chmod 750 ${OKD4_LAB_PATH}/ipxe-work-dir/fcct

# Pull the OKD release tooling identified by ${OKD_REGISTRY}:${OKD_RELEASE}.  i.e. OKD_REGISTRY=registry.svc.ci.openshift.org/origin/release, OKD_RELEASE=4.4.0-0.okd-2020-03-03-170958
if [ ${PULL_RELEASE} == "true" ]
then
  ssh root@${LAB_NAMESERVER} 'sed -i "s|registry.svc.ci.openshift.org|;sinkhole|g" /etc/named/zones/db.sinkhole && systemctl restart named'
  mkdir -p ${OKD4_LAB_PATH}/okd-release-tmp
  cd ${OKD4_LAB_PATH}/okd-release-tmp
  oc adm release extract --command='openshift-install' ${OKD_REGISTRY}:${OKD_RELEASE}
  oc adm release extract --command='oc' ${OKD_REGISTRY}:${OKD_RELEASE}
  mv -f openshift-install ~/bin
  mv -f oc ~/bin
  cd ..
  rm -rf okd-release-tmp
fi
if [ ${USE_MIRROR} == "true" ]
then
  ssh root@${LAB_NAMESERVER} 'sed -i "s|;sinkhole|registry.svc.ci.openshift.org|g" /etc/named/zones/db.sinkhole && systemctl restart named'
fi

# Create and deploy ignition files
rm -rf ${OKD4_LAB_PATH}/okd4-install-dir
mkdir ${OKD4_LAB_PATH}/okd4-install-dir
cp ${OKD4_LAB_PATH}/install-config-upi.yaml ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
OKD_PREFIX=$(echo ${OKD_RELEASE} | cut -d"." -f1,2)
OKD_VER=$(echo ${OKD_RELEASE} | sed  "s|${OKD_PREFIX}.0-0.okd|${OKD_PREFIX}|g")
sed -i "s|%%OKD_VER%%|${OKD_VER}|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
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

  if [ ${NICS} == "2" ]
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

  # Create node specific ignition files
  configIgnition ${IP_01} ${HOSTNAME}.${LAB_DOMAIN} ${NET_MAC_0} ${ROLE}
  cat ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/${NET_MAC_0//:/-}.yml | ${OKD4_LAB_PATH}/ipxe-work-dir/fcct -d ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/ -o ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/${NET_MAC_0//:/-}.ign

  # Create and deploy the iPXE boot file for this VM
  configIpxe ${NET_MAC_0}

  # Create a virtualBMC instance for this VM
  vbmc add --username admin --password password --port ${VBMC_PORT} --address ${BASTION_HOST} --libvirt-uri qemu+ssh://root@${HOST_NODE}.${LAB_DOMAIN}/system ${HOSTNAME}
  vbmc start ${HOSTNAME}
done

ssh root@${INSTALL_HOST} "mkdir -p ${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}"
scp -r ${OKD4_LAB_PATH}/ipxe-work-dir/ignition/*.ign root@${INSTALL_HOST}:${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}/
ssh root@${INSTALL_HOST} "chmod 644 ${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}/*"
scp -r ${OKD4_LAB_PATH}/ipxe-work-dir/*.ipxe root@${PXE_HOST}:/var/lib/tftpboot/ipxe/

# Clean up
rm -rf ${OKD4_LAB_PATH}/ipxe-work-dir
