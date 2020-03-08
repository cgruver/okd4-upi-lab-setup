#!/bin/bash

for i in "$@"
do
case $i in
    -i=*|--inventory=*)
    INVENTORY="${i#*=}"
    shift # past argument=value
    ;;
    -t=*|--type=*)
    TYPE="${i#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

for VARS in $(cat ${INVENTORY} | grep -v "#" | grep ${TYPE})
do
	HOST_NODE=$(echo ${VARS} | cut -d',' -f2)
	HOSTNAME=$(echo ${VARS} | cut -d',' -f3)
	ssh root@${HOST_NODE}.${LAB_DOMAIN} "virsh start ${HOSTNAME}"
done
