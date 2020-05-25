#!/bin/bash

ssh root@${LAB_NAMESERVER} 'sed -i "s|registry.svc.ci.openshift.org|;sinkhole|g" /etc/named/zones/db.sinkhole && systemctl restart named'

oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=${OKD_REGISTRY}:${OKD_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OKD_RELEASE}

OKD_VER=$(echo $OKD_RELEASE | sed  "s|4.4.0-0.okd|4.4|g")
cp ${OKD4_LAB_PATH}/okd-upgrade.yaml ${OKD4_LAB_PATH}/${OKD_VER}.yaml
sed -i "s|%%OKD_VER%%|${OKD_VER}|g" ${OKD4_LAB_PATH}/${OKD_VER}.yaml
oc apply -f ${OKD4_LAB_PATH}/${OKD_VER}.yaml

ssh root@${LAB_NAMESERVER} 'sed -i "s|;sinkhole|registry.svc.ci.openshift.org|g" /etc/named/zones/db.sinkhole && systemctl restart named'
