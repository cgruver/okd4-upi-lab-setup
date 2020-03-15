#!/bin/bash
RESTART_DHCP_2=false

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
  NICS=$(echo ${VARS} | cut -d',' -f7)

  var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
  NET_MAC=$(echo ${var} | cut -d" " -f5)

  # Remove the DHCP reservation
  for i in $(ssh root@${LAB_GATEWAY} "uci show dhcp | grep -w host | grep mac")
  do
    mac=$(echo $i | cut -d"'" -f2)
    index=$(echo $i | cut -d"." -f1,2)
    if [ ${mac} == ${NET_MAC} ]
    then
      echo "Removing existing DHCP Reservation for ${HOSTNAME}"
      ssh root@${LAB_GATEWAY} "uci delete ${index} && uci commit dhcp"
    fi
  done

  if [ ${NICS} == "2" ]
  then
    RESTART_DHCP_2=true
    var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br1")
    NET_MAC_2=$(echo ${var} | cut -d" " -f5)
    # Remove the DHCP reservation
    for i in $(ssh root@${DHCP_2} "uci show dhcp | grep -w host | grep mac")
    do
      mac=$(echo $i | cut -d"'" -f2)
      index=$(echo $i | cut -d"." -f1,2)
      if [ ${mac} == ${NET_MAC_2} ]
      then
        echo "Removing existing DHCP Reservation for ${NET_MAC_2}"
        ssh root@${DHCP_2} "uci delete ${index} && uci commit dhcp"
      fi
    done
  fi
  # Remove the iPXE boot file
  ssh root@${LAB_GATEWAY} "rm -f /data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe"

  # Destroy the VM
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh destroy ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh undefine ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-destroy ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh pool-undefine ${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "rm -rf /VirtualMachines/${HOSTNAME}"
  vbmc delete ${HOSTNAME}
done
# Restart DHCP to make changes effective
echo "Restarting DHCP on ${LAB_GATEWAY}"
ssh root@${LAB_GATEWAY} "/etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"
if [ ${RESTART_DHCP_2} == "true" ]
then
  echo "Restarting DHCP on ${DHCP_2}"
  ssh root@${DHCP_2} "/etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"
fi
# Restore DNS access to registry.svc.ci.openshift.org
ssh root@${LAB_NAMESERVER} 'sed -i "s|registry.svc.ci.openshift.org|;sinkhole|g" /etc/named/zones/db.sinkhole && systemctl restart named'
