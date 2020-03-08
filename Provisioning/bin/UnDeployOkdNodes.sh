#!/bin/bash

for i in "$@"
do
case $i in
  -i=*|--inventory=*)
  INVENTORY="${i#*=}"
  shift # past argument=value
  ;;
  *)
    # unknown option
  ;;
esac
done

for VARS in $(cat ${INVENTORY} | grep -v "#")
do
  HOST_NODE=$(echo ${VARS} | cut -d',' -f2)
  HOSTNAME=$(echo ${VARS} | cut -d',' -f3)
  var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
  NET_MAC=$(echo ${var} | cut -d" " -f5)
  ssh root@${LAB_GATEWAY} "rm -f /data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh destroy ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh undefine ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-destroy ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-undefine ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "rm -rf /VirtualMachines/${HOSTNAME}"
  vbmc delete ${HOSTNAME}
done