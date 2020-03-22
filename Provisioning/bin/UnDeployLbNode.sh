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
    *)
          # unknown option
    ;;
  esac
done

var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
NET_MAC=$(echo ${var} | cut -d" " -f5)

# Remove the iPXE boot file
ssh root@${LAB_GATEWAY} "rm -f /data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe"

# Destroy the VM
ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh destroy ${HOSTNAME}"
ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh undefine ${HOSTNAME}"
ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-destroy ${HOSTNAME}"
ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-undefine ${HOSTNAME}"
ssh root@${HOST_NODE}.${LAB_DOMAIN} "rm -rf /VirtualMachines/${HOSTNAME}"
vbmc delete ${HOSTNAME}

