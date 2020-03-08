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
	TYPE=$(echo ${VARS} | cut -d',' -f1)
	HOST_NODE=$(echo ${VARS} | cut -d',' -f2)
	HOSTNAME=$(echo ${VARS} | cut -d',' -f3)
	MEMORY=$(echo ${VARS} | cut -d',' -f4)
	CPU=$(echo ${VARS} | cut -d',' -f5)
	ROOT_VOL=$(echo ${VARS} | cut -d',' -f6)
	DATA_VOL=$(echo ${VARS} | cut -d',' -f7)
    ROLE=$(echo ${VARS} | cut -d',' -f8)
    if [ ${TYPE} == "PXE" ]
    then # Don't run in parallel
        BuildOscVm.sh -t=${TYPE} -n=${HOST_NODE} -url=${INSTALL_URL} -vm=${HOSTNAME} -m=${MEMORY} -c=${CPU} -gw=${LAB_GATEWAY} -nm=${LAB_NETMASK} -d=${LAB_DOMAIN} -dns=${LAB_NAMESERVER} -dl=${ROOT_VOL},${DATA_VOL} -r=${ROLE}
    else
    	BuildOscVm.sh -t=${TYPE} -n=${HOST_NODE} -url=${INSTALL_URL} -vm=${HOSTNAME} -m=${MEMORY} -c=${CPU} -gw=${LAB_GATEWAY} -nm=${LAB_NETMASK} -d=${LAB_DOMAIN} -dns=${LAB_NAMESERVER} -dl=${ROOT_VOL},${DATA_VOL} -r=${ROLE} &
    fi
done

