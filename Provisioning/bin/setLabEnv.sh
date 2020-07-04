#!/bin/bash

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:/bin:/root/go/bin:/root/bin:~/bin/lab_bin
export LAB_DOMAIN=your.domian.org
export BASTION_HOST=10.11.11.10
export INSTALL_HOST=10.11.11.10
export PXE_HOST=10.11.11.10
export LAB_NAMESERVER=10.11.11.10
export LAB_GATEWAY=10.11.11.1
export LAB_NETMASK=255.255.255.0
export HTML_ROOT=/usr/share/nginx/html
export INSTALL_ROOT=${HTML_ROOT}/install
export REPO_PATH=${HTML_ROOT}/repos
export REPO_URL=http://${INSTALL_HOST}
export INSTALL_URL=http://${INSTALL_HOST}/install
export OKD4_LAB_PATH=/root/okd4-lab
export OKD_REGISTRY=registry.svc.ci.openshift.org/origin/release
export LOCAL_REGISTRY=nexus.${LAB_DOMAIN}:5001
export LOCAL_REPOSITORY=origin
export LOCAL_SECRET_JSON=${OKD4_LAB_PATH}/pull-secret.json
