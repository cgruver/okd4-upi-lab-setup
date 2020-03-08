#!/bin/bash

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

  IP_01=$(dig ${HOSTNAME}.${LAB_DOMAIN} +short)

  ssh root@${HOST_NODE}.${LAB_DOMAIN} "mkdir -p /VirtualMachines/${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virt-install --print-xml 1 --name ${HOSTNAME} --memory ${MEMORY} --vcpus ${CPU} --boot=hd,network,menu=on,useserial=on ${DISK_LIST} --network bridge=br0 --graphics none --noautoconsole --os-variant centos7.0 ${ARGS} > /VirtualMachines/${HOSTNAME}.xml"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh define /VirtualMachines/${HOSTNAME}.xml"
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
  echo "Create DHCP Reservation for ${HOSTNAME}"
  ssh root@${LAB_GATEWAY} "uci add dhcp host && uci set dhcp.@host[-1].name=\"${HOSTNAME}\" && uci set dhcp.@host[-1].mac=\"${NET_MAC}\" && uci set dhcp.@host[-1].ip=\"${IP_01}\" && uci set dhcp.@host[-1].leasetime=\"1m\" && uci commit dhcp && /etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"
  if [ ${ROLE} == "BOOTSTRAP" ]
  then
    ssh root@${LAB_GATEWAY} "ln -s /data/tftpboot/ipxe/templates/bootstrap.ipxe /data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe"
    # ssh root@${INSTALL_HOST_IP} "ln -s ${INSTALL_ROOT}/fcos/ipxe/okd-4/bootstrap.ipxe ${INSTALL_ROOT}/fcos/ipxe/${NET_MAC//:/-}.ipxe"
  elif [ ${ROLE} == "MASTER" ]
  then
    ssh root@${LAB_GATEWAY} "ln -s /data/tftpboot/ipxe/templates/master.ipxe /data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe"
    # ssh root@${INSTALL_HOST_IP} "ln -s ${INSTALL_ROOT}/fcos/ipxe/okd-4/master.ipxe ${INSTALL_ROOT}/fcos/ipxe/${NET_MAC//:/-}.ipxe"
  elif [ ${ROLE} == "WORKER" ]
  then
    ssh root@${LAB_GATEWAY} "ln -s /data/tftpboot/ipxe/templates/worker.ipxe /data/tftpboot/ipxe/${NET_MAC//:/-}.ipxe"
    # ssh root@${INSTALL_HOST_IP} "ln -s ${INSTALL_ROOT}/fcos/ipxe/okd-4/worker.ipxe ${INSTALL_ROOT}/fcos/ipxe/${NET_MAC//:/-}.ipxe"
  fi
  vbmc add --username admin --password password --port ${VBMC_PORT} --address ${INSTALL_HOST_IP} --libvirt-uri qemu+ssh://root@${HOST_NODE}.${LAB_DOMAIN}/system ${HOSTNAME}
  vbmc start ${HOSTNAME}
done
