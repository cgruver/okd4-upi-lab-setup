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
	VBMC_PORT=$(echo ${VARS} | cut -d',' -f9)
    ipmitool -I lanplus -H${BASTION_HOST} -p${VBMC_PORT} -Uadmin -Ppassword chassis power on
done
