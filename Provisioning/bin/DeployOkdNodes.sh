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

  IP_01=$(dig ${HOSTNAME}.${LAB_DOMAIN} +short)
  let O_1=$(echo ${IP_01} | cut -d'.' -f1)
  let O_2=$(echo ${IP_01} | cut -d'.' -f2)
  let O_3=$(echo ${IP_01} | cut -d'.' -f3)
  let O_4=$(echo ${IP_01} | cut -d'.' -f4)
  let O_3=${O_3}+1
  IP_02="${O_1}.${O_2}.${O_3}.${O_4}"

  ssh root@${HOST_NODE}.${LAB_DOMAIN} "mkdir -p /VirtualMachines/${HOSTNAME}"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virt-install --print-xml 1 --name ${HOSTNAME} --memory ${MEMORY} --vcpus ${CPU} --boot=hd,network,menu=on,useserial=on ${DISK_LIST} --network bridge=br0 --network bridge=br1 --graphics none --noautoconsole --os-variant centos7.0 ${ARGS} > /VirtualMachines/${HOSTNAME}.xml"
  ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh define /VirtualMachines/${HOSTNAME}.xml"
  var=$(ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
  NET_MAC=$(echo ${var} | cut -d" " -f5)
  
  sed "s|%%INSTALL_URL%%|${INSTALL_URL}|g" ${OKD4_LAB_PATH}/ipxe_templates/fcos-okd4.ipxe > ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%IP_01%%|${IP_01}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%LAB_GATEWAY%%|${LAB_GATEWAY}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%LAB_NETMASK%%|${LAB_NETMASK}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%HOSTNAME%%|${HOSTNAME}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%IP_02%%|${IP_02}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
  sed -i "s|%%LAB_NAMESERVER%%|${LAB_NAMESERVER}|g" ${OKD4_LAB_PATH}/ipxe-work-dir/${NET_MAC//:/-}.ipxe
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
  vbmc add --username admin --password password --port ${VBMC_PORT} --address ${INSTALL_HOST_IP} --libvirt-uri qemu+ssh://root@${HOST_NODE}.${LAB_DOMAIN}/system ${HOSTNAME}
  vbmc start ${HOSTNAME}
done
rm -rf ${OKD4_LAB_PATH}/ipxe-work-dir