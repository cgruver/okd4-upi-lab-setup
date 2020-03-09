#!/bin/bash

# This script will set up the infrastructure to deploy an OKD 4.X cluster
# Follow the documentation at https://github.com/cgruver/okd4-UPI-Lab-Setup

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
    *)
          # unknown option
    ;;
esac
done

# Pull the OKD release tooling identified by ${OKD_RELEASE}.  i.e. OKD_RELEASE=registry.svc.ci.openshift.org/origin/release:4.4.0-0.okd-2020-03-03-170958
cd ${OKD4_LAB_PATH}
mkdir -p ${OKD4_LAB_PATH}/okd-release-tmp
cd ${OKD4_LAB_PATH}/okd-release-tmp
oc adm release extract --command='openshift-install' ${OKD_RELEASE}
oc adm release extract --command='oc' ${OKD_RELEASE}
mv -f openshift-install ~/bin
mv -f oc ~/bin
cd ..
rm -rf okd-release-tmp
# Create and deploy ignition files
rm -rf ${OKD4_LAB_PATH}/okd4-install-dir
mkdir ${OKD4_LAB_PATH}/okd4-install-dir
cp ${OKD4_LAB_PATH}/install-config-upi.yaml ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir create ignition-configs
scp -r ${OKD4_LAB_PATH}/okd4-install-dir/*.ign root@${INSTALL_HOST_IP}:${INSTALL_ROOT}/fcos/ignition/

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
  ROLE=$(echo ${VARS} | cut -d',' -f7)
  VBMC_PORT=$(echo ${VARS} | cut -d',' -f8)

  DISK_LIST="--disk size=${ROOT_VOL},path=/VirtualMachines/${HOSTNAME}/rootvol,bus=sata"
  ARGS="--cpu host-passthrough,match=exact"

  # Get IP address for eth0
  IP_01=$(dig ${HOSTNAME}.${LAB_DOMAIN} +short)
  let O_1=$(echo ${IP_01} | cut -d'.' -f1)
  let O_2=$(echo ${IP_01} | cut -d'.' -f2)
  let O_3=$(echo ${IP_01} | cut -d'.' -f3)
  let O_4=$(echo ${IP_01} | cut -d'.' -f4)
  let O_3=${O_3}+1
  # IP address for eth1 is the same as eth0 with the third octet incremented by 1.  i.e. eth0=10.10.10.10, eth1=10.10.11.10
  IP_02="${O_1}.${O_2}.${O_3}.${O_4}"

  # Create the VM
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "mkdir -p /VirtualMachines/${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virt-install --print-xml 1 --name ${HOSTNAME} --memory ${MEMORY} --vcpus ${CPU} --boot=hd,network,menu=on,useserial=on ${DISK_LIST} --network bridge=br0 --network bridge=br1 --graphics none --noautoconsole --os-variant centos7.0 ${ARGS} > /VirtualMachines/${HOSTNAME}.xml"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh define /VirtualMachines/${HOSTNAME}.xml"

  # Get the MAC address for eth0 in the new VM  
  var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
  NET_MAC=$(echo ${var} | cut -d" " -f5)
  # Delete any existing DHCP reservations for this host
  for i in $(ssh root@${LAB_GATEWAY} "uci show dhcp | grep -w host | grep name")
  do
    name=$(echo $i | cut -d"'" -f2)
    index=$(echo $i | cut -d"." -f1,2)
    if [ ${name} == ${HOSTNAME} ]
    then
      echo "Removing existing DHCP Reservation for ${HOSTNAME}"
      ssh root@${LAB_GATEWAY} "uci delete ${index} && uci commit dhcp"
    fi
  done
  # Create a DHCP reservation for eth0
  echo "Create DHCP Reservation for ${HOSTNAME}"
  ssh root@${LAB_GATEWAY} "uci add dhcp host && uci set dhcp.@host[-1].name=\"${HOSTNAME}\" && uci set dhcp.@host[-1].mac=\"${NET_MAC}\" && uci set dhcp.@host[-1].ip=\"${IP_01}\" && uci set dhcp.@host[-1].leasetime=\"1m\" && uci commit dhcp"

  # Create and deploy the iPXE boot file for this VM
  sed "s|%%INSTALL_URL%%|${INSTALL_URL}|g" ${OKD4_LAB_PATH}/ipxe-templates/fcos-okd4.ipxe > ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%LAB_NETMASK%%|${LAB_NETMASK}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%IP_02%%|${IP_02}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
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
ssh root@${LAB_GATEWAY} "/etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"

# Clean up
rm -rf ${OKD4_LAB_PATH}/ipxe-work-dir