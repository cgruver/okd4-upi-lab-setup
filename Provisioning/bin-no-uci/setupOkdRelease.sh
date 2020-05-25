#!/bin/bash

cd ${OKD4_LAB_PATH}

mkdir -p ${OKD4_LAB_PATH}/okd-release-tmp
cd ${OKD4_LAB_PATH}/okd-release-tmp
oc adm release extract --command='openshift-install' ${OKD_RELEASE}
oc adm release extract --command='oc' ${OKD_RELEASE}
mv -f openshift-install ~/bin
mv -f oc ~/bin
cd ..
rm -rf okd-release-tmp

rm -rf ${OKD4_LAB_PATH}/okd4-install-dir
mkdir ${OKD4_LAB_PATH}/okd4-install-dir
cp ${OKD4_LAB_PATH}/install-config-upi.yaml ${OKD4_LAB_PATH}/okd4-install-dir/install-config.yaml
openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir create ignition-configs
scp -r ${OKD4_LAB_PATH}/okd4-install-dir/*.ign root@${INSTALL_HOST_IP}:${INSTALL_ROOT}/fcos/ignition/