#!/bin/bash

for i in "$@"
do
case $i in
    -i=*|--inventory=*)
    INVENTORY="${i#*=}"
    shift # past argument=value
    ;;
    -s=*|--source=*)
    SOURCE="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--dest=*)
    DEST="${i#*=}"
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
	scp ${SOURCE} root@${HOSTNAME}.${LAB_DOMAIN}:/${DEST}
done
