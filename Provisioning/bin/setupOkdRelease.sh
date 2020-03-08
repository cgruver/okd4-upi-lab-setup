#!/bin/bash

mkdir -p ~/okd4-lab/okd-release-tmp
cd ~/okd4-lab/okd-release-tmp
oc adm release extract --command='openshift-install' ${OKD_RELEASE}
oc adm release extract --command='oc' ${OKD_RELEASE}
mv -f openshift-install ~/bin
mv -f oc ~/bin

cd ..
rm -rf okd-release-tmp

rm -rf okd4-install
mkdir okd4-install
cp ${OKD_INSTALL_CONFIG} okd4-install/install-config.yaml
openshift-install --dir=okd4-install create ignition-configs
cp -f okd4-install/*.ign ${INSTALL_ROOT}/fcos/ignition/

