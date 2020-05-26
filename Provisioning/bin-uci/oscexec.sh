#!/bin/bash

for i in "$@"
do
case $i in
    -i=*|--inventory=*)
    INVENTORY="${i#*=}"
    shift # past argument=value
    ;;
    -c=*|--command=*)
    CMD="${i#*=}"
    shift # past argument=value
    ;;
    *)
          # unknown option
    ;;
esac
done

for VARS in $(cat ${INVENTORY} | grep -v "#")
do
	HOSTNAME=$(echo ${VARS} | cut -d',' -f3)
	echo ${HOSTNAME}
	ssh -oStrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${HOSTNAME}.${LAB_DOMAIN} "${CMD}"
done

