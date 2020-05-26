#!/bin/bash

for i in "$@"
do
case $i in
    -h=*|--hostname=*)
    HOSTNAME="${i#*=}"
    shift # past argument=value
    ;;
    -n=*|--node=*)
    HOST_NODE="${i#*=}"
    shift # past argument=value
    ;;
    -v=*|--vbmc=*)
    VBMC_PORT="${i#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

# Create Virtual Machines from the inventory file
mkdir -p ${OKD4_LAB_PATH}/ipxe-work-dir

# Get IP address for eth0
IP_01=$(dig ${HOSTNAME}.${LAB_DOMAIN} +short)

# Create the VM
ssh root@${HOST_NODE}.${LAB_DOMAIN} "mkdir -p /VirtualMachines/${HOSTNAME}"
ssh root@${HOST_NODE}.${LAB_DOMAIN} "virt-install --print-xml 1 --name ${HOSTNAME} --memory 4096 --vcpus 2 --boot=hd,network,menu=on,useserial=on --disk size=50,path=/VirtualMachines/${HOSTNAME}/rootvol,bus=sata --network bridge=br0 --graphics none --noautoconsole --os-variant centos7.0 > /VirtualMachines/${HOSTNAME}.xml"
ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh define /VirtualMachines/${HOSTNAME}.xml"

# Get the MAC address for eth0 in the new VM  
var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
NET_MAC=$(echo ${var} | cut -d" " -f5)
  
IP_CONFIG="ip=${IP_01}::${LAB_GATEWAY}:${LAB_NETMASK}:${HOSTNAME}.${LAB_DOMAIN}:eth0:none nameserver=${LAB_NAMESERVER}"

# Create and deploy the iPXE boot file for this VM
sed "s|%%IP_CONFIG%%|${IP_CONFIG}|g" ${OKD4_LAB_PATH}/ipxe-templates/okd-lb.ipxe > ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
scp ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe root@${LAB_GATEWAY}:/data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe

# Create a virtualBMC instance for this VM
vbmc add --username admin --password password --port ${VBMC_PORT} --address ${INSTALL_HOST_IP} --libvirt-uri qemu+ssh://root@${HOST_NODE}.${LAB_DOMAIN}/system ${HOSTNAME}
vbmc start ${HOSTNAME}

# Clean up
rm -rf ${OKD4_LAB_PATH}/ipxe-work-dir
