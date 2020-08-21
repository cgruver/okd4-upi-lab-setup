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
  HOSTNAME=$(echo ${VARS} | cut -d'|' -f1)
  DISK=$(echo ${VARS} | cut -d'|' -f2)
  MAC=$(echo ${VARS} | cut -d'|' -f3)

  DeployKvmHost.sh -h=${HOSTNAME} -m=${MAC} -d=${DISK}
done
