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
  HOST_NODE=$(echo ${VARS} | cut -d',' -f1)
  HOSTNAME=$(echo ${VARS} | cut -d',' -f2)
  var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
  NET_MAC=$(echo ${var} | cut -d" " -f5)
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
  ssh root@${LAB_GATEWAY} "rm -f /data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh destroy ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh undefine ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-destroy ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-undefine ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "rm -rf /VirtualMachines/${HOSTNAME}"
  vbmc delete ${HOSTNAME}
done
ssh root@${LAB_GATEWAY} "/etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"