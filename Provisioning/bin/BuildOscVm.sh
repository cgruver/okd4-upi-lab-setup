#!/bin/bash

for i in "$@"
do
case $i in
    -t=*|--type=*)
    TYPE="${i#*=}"
    shift 
    ;;
    -r=*|--role=*)
    ROLE="${i#*=}"
    shift 
    ;;
    -n=*|--hostnode=*)
    NODE="${i#*=}"
    shift 
    ;;
    -url=*|--install-url=*)
    INSTALL_URL="${i#*=}"
    shift
    ;;
    -vm=*|--vmhostname=*)
    HOSTNAME="${i#*=}"
    shift 
    ;;
    -m=*|--memory=*)
    MEMORY="${i#*=}"
    shift 
    ;;
    -c=*|--cpu=*)
    CPU="${i#*=}"
    shift 
    ;;
    -gw=*|--gateway=*)
    LAB_GATEWAY="${i#*=}"
    shift 
    ;;
    -nm=*|--netmask=*)
    LAB_NETMASK="${i#*=}"
    shift 
    ;;
    -d=*|--domain=*)
    LAB_DOMAIN="${i#*=}"
    shift 
    ;;
    -dns=*|--nameserver=*)
    LAB_NAMESERVER="${i#*=}"
    shift 
    ;;
    -dl=*|--disklist=*)
    DISK_LIST="${i#*=}"
    shift 
    ;;
    *)
          # unknown option
    ;;
esac
done

D1_SIZE=$(echo $DISK_LIST | cut -d"," -f1)
D2_SIZE=$(echo $DISK_LIST | cut -d"," -f2)

DISK_LIST="--disk size=${D1_SIZE},path=/VirtualMachines/${HOSTNAME}/rootvol,boot_order=1,bus=sata --disk size=${D2_SIZE},path=/VirtualMachines/${HOSTNAME}/dockervol,bus=sata"

KS="${INSTALL_URL}/kickstart"
ARGS=""

case $TYPE in
	OKD)
	KS="${KS}/okddev.ks"
	DISK_LIST="--disk size=${D1_SIZE},path=/VirtualMachines/${HOSTNAME}/rootvol,boot_order=1,bus=sata"
	ARGS="--cpu host-passthrough,match=exact"
	;;
	DEV)
	KS="${KS}/devnode.ks"
	DISK_LIST="--disk size=${D1_SIZE},path=/VirtualMachines/${HOSTNAME}/rootvol,boot_order=1,bus=sata"
	;;
	ROUTER)
	KS="${KS}/rtenode.ks"
	DISK_LIST="--disk size=${D1_SIZE},path=/VirtualMachines/${HOSTNAME}/rootvol,boot_order=1,bus=sata"
	;;
	MASTER)
	KS="${KS}/okd-kvm-node.ks"
	;;
	INFRA)
	KS="${KS}/okd-kvm-node.ks"
	;;
	APP)
	KS="${KS}/okd-kvm-node.ks"
	;;
	SAN)
	KS="${KS}/sannode.ks"
	DISK_LIST="--disk size=${D1_SIZE},path=/VirtualMachines/${HOSTNAME}/rootvol,boot_order=1,bus=sata --disk size=${D2_SIZE},path=/VirtualMachines/${HOSTNAME}/glustervol,bus=sata"
	;;
	DB)
	KS="${KS}/dbnode.ks"
	DISK_LIST="--disk size=${D1_SIZE},path=/VirtualMachines/${HOSTNAME}/rootvol,boot_order=1,bus=sata --disk size=${D2_SIZE},path=/VirtualMachines/${HOSTNAME}/datavol,bus=sata"
	;;
    PXE)
    DISK_LIST="--disk size=${D1_SIZE},path=/VirtualMachines/${HOSTNAME}/rootvol,bus=sata"
    ARGS="--cpu host-passthrough,match=exact"
    ;;
esac

IP_01=$(dig ${HOSTNAME}.${LAB_DOMAIN} +short)
let O_1=$(echo ${IP_01} | cut -d'.' -f1)
let O_2=$(echo ${IP_01} | cut -d'.' -f2)
let O_3=$(echo ${IP_01} | cut -d'.' -f3)
let O_4=$(echo ${IP_01} | cut -d'.' -f4)
let O_3=${O_3}+1
IP_02="${O_1}.${O_2}.${O_3}.${O_4}"

ssh root@${NODE}.${LAB_DOMAIN} "mkdir -p /VirtualMachines/${HOSTNAME}"

if [ ${TYPE} == "PXE" ]
then
    ssh root@${NODE}.${LAB_DOMAIN} "virt-install --print-xml 1 --name ${HOSTNAME} --memory ${MEMORY} --vcpus ${CPU} --boot=hd,network,menu=on,useserial=on ${DISK_LIST} --network bridge=br0 --graphics none --noautoconsole --os-variant centos7.0 ${ARGS} > /VirtualMachines/${HOSTNAME}.xml"
    ssh root@${NODE}.${LAB_DOMAIN} "virsh define /VirtualMachines/${HOSTNAME}.xml"
    var=$(ssh root@${NODE}.${LAB_DOMAIN} "virsh -q domiflist ${HOSTNAME} | grep br0")
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
    echo "Create DHCP Reservation"
    ssh root@${LAB_GATEWAY} "uci add dhcp host && uci set dhcp.@host[-1].name=\"${HOSTNAME}\" && uci set dhcp.@host[-1].mac=\"${NET_MAC}\" && uci set dhcp.@host[-1].ip=\"${IP_01}\" && uci set dhcp.@host[-1].leasetime=\"1m\" && uci commit dhcp && /etc/init.d/dnsmasq restart && /etc/init.d/odhcpd restart"
    IGN_FILE=${NET_MAC//:/-}
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
else
    ssh root@${NODE}.${LAB_DOMAIN} "virt-install --name ${HOSTNAME} --memory ${MEMORY} --vcpus ${CPU} --location ${INSTALL_URL}/centos ${DISK_LIST} --extra-args=\"inst.ks=${KS} ip=${IP_01}::${LAB_GATEWAY}:${LAB_NETMASK}:${HOSTNAME}.${LAB_DOMAIN}:eth0:none ip=${IP_02}:::${LAB_NETMASK}::eth1:none nameserver=${LAB_NAMESERVER} console=tty0 console=ttyS0,115200n8\" --network bridge=br0 --network bridge=br1 --graphics none --noautoconsole --os-variant centos7.0 --wait=-1 ${ARGS}"
fi
