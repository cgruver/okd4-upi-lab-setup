#!/bin/bash

# This script will set up the infrastructure to deploy an OKD 4.X cluster
# Follow the documentation at https://github.com/cgruver/okd4-UPI-Lab-Setup
PULL_RELEASE=false
USE_MIRROR=false
RESTART_DHCP_1=false
RESTART_DHCP_2=false
IP_CONFIG_1=""
IP_CONFIG_2=""
IP_CONFIG=""
DHCP_1=false
DHCP_2=false
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
    -m|--mirror)
    USE_MIRROR=true
    shift
    ;;
    -p|--pull-release)
    PULL_RELEASE=true
    shift
    ;;
    -n=*|--name=*)
    CLUSTER_NAME="${i#*=}"
    shift
    ;;
    -d1|--dhcp-nic1)
    DHCP_1=true
    shift
    ;;
    -d2|--dhcp-nic2)
    DHCP_2=true
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done


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
OKD_VER=$(echo $OKD_RELEASE | sed  "s|4.4.0-0.okd|4.4|g")
sed -i "s|%%OKD_VER%%|${OKD_VER}|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
sed -i "s|%%CLUSTER_NAME%%|${CLUSTER_NAME}|g" ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir create ignition-configs
ssh root@${INSTALL_HOST_IP} "mkdir -p ${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}"
scp -r ${OKD4_LAB_PATH}/okd4-install-dir/*.ign root@${INSTALL_HOST_IP}:${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}/
ssh root@${INSTALL_HOST_IP} "chmod 644 ${INSTALL_ROOT}/fcos/ignition/${CLUSTER_NAME}/*"

# Create Virtual Machines from the inventory file
mkdir -p ${OKD4_LAB_PATH}/ipxe-work-dir
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
  let O_1=$(echo ${IP_01} | cut -d'.' -f1)
  let O_2=$(echo ${IP_01} | cut -d'.' -f2)
  let O_3=$(echo ${IP_01} | cut -d'.' -f3)
  let O_4=$(echo ${IP_01} | cut -d'.' -f4)
  let O_3=${O_3}+1
  # IP address for eth1 is the same as eth0 with the third octet incremented by 1.  i.e. eth0=10.11.11.10, eth1=10.11.12.10
  IP_02="${O_1}.${O_2}.${O_3}.${O_4}"

  if [ ${NICS} == "2" ]
  then
    NET_DEVICE="--network bridge=br0 --network bridge=br1"
  else
    NET_DEVICE="--network bridge=br0"
  fi

  # Create the VM
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "mkdir -p /VirtualMachines/${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virt-install --print-xml 1 --name ${HOSTNAME} --memory ${MEMORY} --vcpus ${CPU} --boot=hd,network,menu=on,useserial=on ${DISK_LIST} ${NET_DEVICE} --graphics none --noautoconsole --os-variant centos7.0 ${ARGS} > /VirtualMachines/${HOSTNAME}.xml"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh define /VirtualMachines/${HOSTNAME}.xml"

  # Get the MAC address for eth0 in the new VM  
  var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
  NET_MAC=$(echo ${var} | cut -d" " -f5)
  if [ ${DHCP_1} == "true" ]
  then
    IP_CONFIG_1="ip=:::::eth0:dhcp"
    RESTART_DHCP_1=true
    # Delete any existing DHCP reservations for this host
    for i in $(ssh root@${LAB_GATEWAY} "uci show dhcp | grep -w host | grep ip")
    do
      ip=$(echo $i | cut -d"'" -f2)
      index=$(echo $i | cut -d"." -f1,2)
      if [ ${ip} == ${IP_01} ]
      then
        echo "Removing existing DHCP Reservation for ${HOSTNAME}"
        ssh root@${LAB_GATEWAY} "uci delete ${index} && uci commit dhcp"
      fi
    done
    # Create a DHCP reservation for eth0
    echo "Create DHCP Reservation for ${HOSTNAME}"
    ssh root@${LAB_GATEWAY} "uci add dhcp host && uci set dhcp.@host[-1].name=\"${HOSTNAME}\" && uci set dhcp.@host[-1].mac=\"${NET_MAC}\" && uci set dhcp.@host[-1].ip=\"${IP_01}\" && uci set dhcp.@host[-1].leasetime=\"1m\" && uci commit dhcp"
  else
    IP_CONFIG_1="ip=${IP_01}::${LAB_GATEWAY}:${LAB_NETMASK}:${HOSTNAME}.${LAB_DOMAIN}:eth0:none nameserver=${LAB_NAMESERVER}"
  fi

  if [ ${DHCP_2} == "true" ] && [ ${NICS} == "2" ]
  then
    IP_CONFIG_2="ip=:::::eth1:dhcp"
    RESTART_DHCP_2=true
    # Get the MAC address for eth1 in the new VM  
    var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br1")
    NET_MAC_2=$(echo ${var} | cut -d" " -f5)
    # Delete any existing DHCP reservations for this host
    for i in $(ssh root@${DHCP_2} "uci show dhcp | grep -w host | grep ip")
    do
      ip=$(echo $i | cut -d"'" -f2)
      index=$(echo $i | cut -d"." -f1,2)
      if [ ${ip} == ${IP_02} ]
      then
        echo "Removing existing DHCP Reservation for ${IP_02}"
        ssh root@${DHCP_2} "uci delete ${index} && uci commit dhcp"
      fi
    done
    # Create a DHCP reservation for eth0
    echo "Create DHCP Reservation for ${IP_02}"
    ssh root@${DHCP_2} "uci add dhcp host && uci set dhcp.@host[-1].mac=\"${NET_MAC_2}\" && uci set dhcp.@host[-1].ip=\"${IP_02}\" && uci set dhcp.@host[-1].leasetime=\"1m\" && uci commit dhcp"
  elif [ ${NICS} == "2" ]
  then
    IP_CONFIG_2="ip=${IP_02}:::${LAB_NETMASK}::eth1:none"
  fi
  IP_CONFIG="${IP_CONFIG_1} ${IP_CONFIG_2}"

  # Create and deploy the iPXE boot file for this VM
  sed "s|%%IP_CONFIG%%|${IP_CONFIG}|g" ${OKD4_LAB_PATH}/ipxe-templates/fcos-okd4.ipxe > ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%CLUSTER_NAME%%|${CLUSTER_NAME}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  if [ ${ROLE} == "BOOTSTRAP" ]
  then
    sed -i "s|%%OKD_ROLE%%|bootstrap|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  elif [ ${ROLE} == "MASTER" ]
  then
    sed -i "s|%%OKD_ROLE%%|master|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  elif [ ${ROLE} == "WORKER" ]
  then
    sed -i "s|%%OKD_ROLE%%|worker|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  fi
  scp ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe root@${LAB_GATEWAY}:/data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe

  # Create a virtualBMC instance for this VM
  vbmc add --username admin --password password --port ${VBMC_PORT} --address ${INSTALL_HOST_IP} --libvirt-uri qemu+ssh://root@${HOST_NODE}.${LAB_DOMAIN}/system ${HOSTNAME}
  vbmc start ${HOSTNAME}
done

# Restart the DHCP server to make the DHCP reservations active
if [ ${RESTART_DHCP_1} == "true" ]
then
  echo "Restarting DHCP on ${LAB_GATEWAY}"
  ssh root@${LAB_GATEWAY} "/etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"
fi
if [ ${RESTART_DHCP_2} == "true" ]
then
  echo "Restarting DHCP on ${DHCP_2}"
  ssh root@${DHCP_2} "/etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"
fi
# Clean up
rm -rf ${OKD4_LAB_PATH}/ipxe-work-dir
