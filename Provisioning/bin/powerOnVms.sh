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
    ipmitool -I lanplus -H${INSTALL_HOST_IP} -p${VBMC_PORT} -Uadmin -Ppassword chassis power on
done
