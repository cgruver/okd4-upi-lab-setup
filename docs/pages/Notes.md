# Notes before they become docs

## Reset the HA Proxy configuration for a new cluster build:

```bash
ssh okd4-lb01 "curl -o /etc/haproxy/haproxy.cfg http://${INSTALL_HOST}/install/postinstall/haproxy.cfg && systemctl restart haproxy"
```

## Upgrade:

```bash
oc adm upgrade 

Cluster version is 4.4.0-0.okd-2020-04-09-104654

Updates:

VERSION                       IMAGE
4.4.0-0.okd-2020-04-09-113408 registry.svc.ci.openshift.org/origin/release@sha256:724d170530bd738830f0ba370e74d94a22fc70cf1c017b1d1447d39ae7c3cf4f
4.4.0-0.okd-2020-04-09-124138 registry.svc.ci.openshift.org/origin/release@sha256:ce16ac845c0a0d178149553a51214367f63860aea71c0337f25556f25e5b8bb3

ssh root@${LAB_NAMESERVER} 'sed -i "s|registry.svc.ci.openshift.org|;sinkhole|g" /etc/named/zones/db.sinkhole && systemctl restart named'

export OKD_RELEASE=4.4.0-0.okd-2020-04-09-124138

oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=${OKD_REGISTRY}:${OKD_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OKD_RELEASE}

oc apply -f upgrade.yaml

ssh root@${LAB_NAMESERVER} 'sed -i "s|;sinkhole|registry.svc.ci.openshift.org|g" /etc/named/zones/db.sinkhole && systemctl restart named'

oc adm upgrade --to=${OKD_RELEASE}


oc patch clusterversion/version --patch '{"spec":{"upstream":"https://origin-release.svc.ci.openshift.org/graph"}}' --type=merge
```

## Samples Operator: Extract templates and image streams, then remove the operator.  We don't want everything and the kitchen sink...

```bash
mkdir -p ${OKD4_LAB_PATH}/OKD-Templates-ImageStreams/templates
mkdir ${OKD4_LAB_PATH}/OKD-Templates-ImageStreams/image-streams
oc project openshift
oc get template | grep -v NAME | while read line
do
    TEMPLATE=$(echo $line | cut -d' ' -f1)
    oc get --export template ${TEMPLATE} -o yaml > ${OKD4_LAB_PATH}/OKD-Templates-ImageStreams/templates/${TEMPLATE}.yml
done

oc get is | grep -v NAME | while read line
do
    IS=$(echo $line | cut -d' ' -f1)
    oc get --export is ${IS} -o yaml > ${OKD4_LAB_PATH}/OKD-Templates-ImageStreams/image-streams/${IS}.yml
done

oc patch configs.samples.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Removed"}}'
```

## Fix Hostname:

```bash
for i in 0 1 2 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-${i}.${LAB_DOMAIN} "sudo hostnamectl set-hostname okd4-master-${i}.my.domain.org && sudo shutdown -r now"; done
for i in 0 1 2 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-worker-${i}.${LAB_DOMAIN} "sudo hostnamectl set-hostname okd4-worker-${i}.my.domain.org && sudo shutdown -r now"; done
```

## Logs:

```bash
for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-${i}.${LAB_DOMAIN} "sudo journalctl --disk-usage"; done
for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-worker-${i}.${LAB_DOMAIN} "sudo journalctl --disk-usage"; done

for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-${i}.${LAB_DOMAIN} "sudo journalctl --vacuum-time=1s"; done
for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-worker-${i}.${LAB_DOMAIN} "sudo journalctl --vacuum-time=1s"; done
```

## Project Provisioning:

```bash
oc describe clusterrolebinding.rbac self-provisioners

# Remove self-provisioning from all roles
oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'

# Remove from specific role
oc adm policy remove-cluster-role-from-group self-provisioner system:authenticated:oauth

# Prevent automatic updates to the role
oc patch clusterrolebinding.rbac self-provisioners -p '{ "metadata": { "annotations": { "rbac.authorization.kubernetes.io/autoupdate": "false" } } }'
```

## iSCSI:

```bash
echo "InitiatorName=iqn.$(hostname)" > /etc/iscsi/initiatorname.iscsi
systemctl enable iscsid --now

iscsiadm -m  discovery -t st -l -p 10.11.11.5:3260

for i in 0 1 2 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-prd-master-${i}.${LAB_DOMAIN} "sudo bash -c \"echo InitiatorName=iqn.$(hostname) > /etc/iscsi/initiatorname.iscsi\" && sudo systemctl enable iscsid --now"; done

for i in 0 1 2 3 4 5 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-prd-worker-${i}.${LAB_DOMAIN} "sudo bash -c \"echo InitiatorName=iqn.$(hostname) > /etc/iscsi/initiatorname.iscsi\" && sudo systemctl enable iscsid --now"; done
```

## FCCT:

```bash
wget https://github.com/coreos/fcct/releases/download/v0.6.0/fcct-x86_64-unknown-linux-gnu
mv fcct-x86_64-unknown-linux-gnu ~/bin/lab_bin/fcct 
chmod 750 ~/bin/lab_bin/fcct
```

```yaml
# Merge some tweaks/bugfixes with the master Ignition config
variant: fcos
version: 1.1.0
ignition:
  config:
    merge:
      - local: ./files/master.ign
systemd:                        
  units:                        
  # we don't want docker starting
  # https://github.com/openshift/okd/issues/243
  - name: docker.service
    mask: true
storage:
  files:
    # Disable zincati, this should be removed in the next OKD beta
    # https://github.com/openshift/machine-config-operator/pull/1890
    # https://github.com/openshift/okd/issues/215
    - path: /etc/zincati/config.d/90-disable-feature.toml
      contents:
        inline: |
          [updates]
          enabled = false
    - path: /etc/systemd/network/25-nic0.link
      mode: 0644
      contents:
        inline: |
          [Match]
          MACAddress=${NET_MAC_0}
          [Link]
          Name=nic0
    - path: /etc/NetworkManager/system-connections/nic0.nmconnection
      mode: 0600
      overwrite: true
      contents:
        inline: |
          [connection]
          type=ethernet
          interface-name=nic0

          [ethernet]
          mac-address=<insert MAC address>

          [ipv4]
          method=manual
          addresses=192.0.2.10/24
          gateway=192.0.2.1
          dns=192.168.124.1;1.1.1.1;8.8.8.8
          dns-search=redhat.com
```

## iPXE:

```bash
wget http://boot.ipxe.org/ipxe.efi
```

```bash
uci add_list dhcp.lan.dhcp_option="6,10.11.11.10,8.8.8.8,8.8.4.4"
uci set dhcp.@dnsmasq[0].enable_tftp=1
uci set dhcp.@dnsmasq[0].tftp_root=/data/tftpboot
uci set dhcp.efi64_boot_1=match
uci set dhcp.efi64_boot_1.networkid='set:efi64'
uci set dhcp.efi64_boot_1.match='60,PXEClient:Arch:00007'
uci set dhcp.efi64_boot_2=match
uci set dhcp.efi64_boot_2.networkid='set:efi64'
uci set dhcp.efi64_boot_2.match='60,PXEClient:Arch:00009'
uci set dhcp.ipxe_boot=userclass
uci set dhcp.ipxe_boot.networkid='set:ipxe'
uci set dhcp.ipxe_boot.userclass='iPXE'
uci set dhcp.uefi=boot
uci set dhcp.uefi.filename='tag:efi64,tag:!ipxe,ipxe.efi'
uci set dhcp.uefi.serveraddress='10.11.11.1'
uci set dhcp.uefi.servername='pxe'
uci set dhcp.uefi.force='1'
uci set dhcp.ipxe=boot
uci set dhcp.ipxe.filename='tag:ipxe,boot.ipxe'
uci set dhcp.ipxe.serveraddress='10.11.11.1'
uci set dhcp.ipxe.servername='pxe'
uci set dhcp.ipxe.force='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

## Journald

```bash
sed -i 's/#Storage.*/Storage=persistent/' /etc/systemd/journald.conf
sed -i 's/#SystemMaxUse.*/SystemMaxUse=4G/' /etc/systemd/journald.conf
systemctl restart systemd-journald.service
```

## KubeVirt

### Node Maintenance Operator

```bash
git clone https://github.com/kubevirt/node-maintenance-operator.git
cd node-maintenance-operator/

oc apply -f deploy/deployment-ocp/catalogsource.yaml
oc apply -f deploy/deployment-ocp/namespace.yaml
oc apply -f deploy/deployment-ocp/operatorgroup.yaml
oc apply -f deploy/deployment-ocp/subscription.yaml
```

### Hyperconverged Cluster Operator

```bash
export REGISTRY_NAMESPACE=kubevirt
export IMAGE_REGISTRY=${LOCAL_REGISTRY}
export TAG=4.6
export CONTAINER_TAG=4.6
export OPERATOR_IMAGE=hyperconverged-cluster-operator
export CONTAINER_BUILD_CMD=podman
export WORK_DIR=${OKD4_LAB_PATH}/kubevirt

git clone https://github.com/kubevirt/hyperconverged-cluster-operator.git

git checkout release-4.6`

podman build -f build/Dockerfile -t ${LOCAL_REGISTRY}/${REGISTRY_NAMESPACE}/${OPERATOR_IMAGE}:${TAG} --build-arg git_sha=$(shell git describe --no-match  --always --abbrev=40 --dirty) .

podman build -f tools/operator-courier/Dockerfile -t hco-courier .
podman tag hco-courier:latest  ${LOCAL_REGISTRY}/${REGISTRY_NAMESPACE}/hco-courier:latest
podman tag hco-courier:latest  ${LOCAL_REGISTRY}/${REGISTRY_NAMESPACE}/hco-courier:${TAG}

podman login ${LOCAL_REGISTRY}

podman push ${LOCAL_REGISTRY}/${REGISTRY_NAMESPACE}/${OPERATOR_IMAGE}:${TAG}
podman push ${LOCAL_REGISTRY}/${REGISTRY_NAMESPACE}/hco-courier:latest
podman push ${LOCAL_REGISTRY}/${REGISTRY_NAMESPACE}/hco-courier:${TAG}

./hack/build-registry-bundle.sh

cd ${WORK_DIR}

cat <<EOF > ${WORK_DIR}/operator-group.yml 
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: hco-operatorgroup
  namespace: kubevirt-hyperconverged
spec:
  targetNamespaces:
  - "kubevirt-hyperconverged"
EOF

cat <<EOF > ${WORK_DIR}/catalog-source.yml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: hco-catalogsource
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${IMAGE_REGISTRY}/${REGISTRY_NAMESPACE}/hco-container-registry:${CONTAINER_TAG}
  displayName: KubeVirt HyperConverged
  publisher: ${LAB_DOMAIN}
  updateStrategy:
    registryPoll:
      interval: 30m
EOF

cat <<EOF > subscription.yml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-subscription
  namespace: kubevirt-hyperconverged
spec:
  channel: "1.0.0"
  name: kubevirt-hyperconverged
  source: hco-catalogsource
  sourceNamespace: openshift-marketplace
EOF

oc create -f hco.cr.yaml -n kubevirt-hyperconverged

export KUBEVIRT_PROVIDER="okd-4.5"
```

### KubeVirt project:

```bash
# export DOCKER_PREFIX=${LOCAL_REGISTRY}/kubevirt
# export DOCKER_TAG=okd-4.5
```

### Chrony

https://docs.openshift.com/container-platform/4.5/installing/install_config/installing-customizing.html

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-crhony-master
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,<crony configuration base64 encode>
        filesystem: root
        mode: 420
        path: /etc/chrony.conf
```

```bash
cat << EOF | base64
server clock.redhat.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

cat << EOF > ./99_masters-chrony-configuration.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: masters-chrony-configuration
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 2.2.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,c2VydmVyIGNsb2NrLnJlZGhhdC5jb20gaWJ1cnN0CmRyaWZ0ZmlsZSAvdmFyL2xpYi9jaHJvbnkvZHJpZnQKbWFrZXN0ZXAgMS4wIDMKcnRjc3luYwpsb2dkaXIgL3Zhci9sb2cvY2hyb255Cg==
          verification: {}
        filesystem: root
        mode: 420
        path: /etc/chrony.conf
  osImageURL: ""
EOF
```

## CRC for OKD:

### One time setup

```bash
dnf install jq golang-bin gcc-c++ golang make

firewall-cmd --add-rich-rule "rule service name="libvirt" reject" --permanent
firewall-cmd --zone=dmz --change-interface=tt0 --permanent
firewall-cmd --zone=dmz --add-service=libvirt --permanent
firewall-cmd --zone=dmz --add-service=dns --permanent
firewall-cmd --zone=dmz --add-service=dhcp --permanent
firewall-cmd --reload

cat <<EOF >> /etc/libvirt/libvirtd.conf
listen_tls = 0
listen_tcp = 1
auth_tcp = "none"
tcp_port = "16509"
EOF

cat <<EOF >> /etc/sysconfig/libvirtd
LIBVIRTD_ARGS="--listen"
EOF

systemctl restart libvirtd

cat <<EOF > /etc/NetworkManager/conf.d/openshift.conf
[main]
dns=dnsmasq
EOF

cat <<EOF > /etc/NetworkManager/dnsmasq.d/openshift.conf
server=/crc.testing/192.168.126.1
address=/apps-crc.testing/192.168.126.11
EOF

systemctl reload NetworkManager

```

### Build SNC:

```bash

cat << EOF > /tmp/pull_secret.json
{"auths":{"fake":{"auth": "Zm9vOmJhcgo="}}}
EOF

cd /tmp

git clone https://github.com/cgruver/crc.git
git clone https://github.com/cgruver/snc.git

cd snc
git checkout okd

export OKD_VERSION=4.5.0-0.okd-2020-09-04-180756
export OPENSHIFT_PULL_SECRET_PATH="/tmp/pull_secret.json"
./snc.sh

# Watch progress:
export KUBECONFIG=crc-tmp-install-data/auth/kubeconfig 
./oc get pods --all-namespaces

# Rotate Certs:
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i id_rsa_crc core@api.crc.testing -- sudo openssl x509 -checkend 2160000 -noout -in /var/lib/kubelet/pki/kubelet-client-current.pem

./oc delete secrets/csr-signer-signer secrets/csr-signer -n openshift-kube-controller-manager-operator
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i id_rsa_crc core@api.crc.testing -- sudo rm -fr /var/lib/kubelet/pki
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i id_rsa_crc core@api.crc.testing -- sudo rm -fr /var/lib/kubelet/kubeconfig
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i id_rsa_crc core@api.crc.testing -- sudo systemctl restart kubelet

./oc get csr
./oc get csr '-ojsonpath={.items[*].metadata.name}' | xargs ./oc adm certificate approve

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i id_rsa_crc core@api.crc.testing -- sudo openssl x509 -checkend 2160000 -noout -in /var/lib/kubelet/pki/kubelet-client-current.pem

# Clean up Ingress:

./oc get pods --all-namespaces | grep NodeAffinity | while read i
do
    NS=$(echo ${i} | cut -d" " -f1 )
    POD=$(echo ${i} | cut -d" " -f2 )
    ./oc delete pod ${POD} -n ${NS}
done

./oc get pods --all-namespaces | grep CrashLoop | while read i
do
    NS=$(echo ${i} | cut -d" " -f1 )
    POD=$(echo ${i} | cut -d" " -f2 )
    ./oc delete pod ${POD} -n ${NS}
done

./createdisk.sh crc-tmp-install-data

cd ../crc
git checkout okd

export OC_BASE_URL=https://github.com/openshift/okd/releases/download
export BUNDLE_VERSION=${OKD_VERSION}
export BUNDLE_DIR=/tmp/snc
make embed_bundle

```

### Clean up VMs:

```bash

CRC=$(virsh net-list --all | grep crc- | cut -d" " -f2)
virsh destroy ${CRC}-bootstrap
virsh undefine ${CRC}-bootstrap
virsh destroy ${CRC}-master-0
virsh undefine ${CRC}-master-0
virsh net-destroy ${CRC}
virsh net-undefine ${CRC}
virsh pool-destroy ${CRC}
virsh pool-undefine ${CRC}
rm -rf /var/lib/libvirt/openshift-images/${CRC}

```

### Rebase Git

```bash
git remote add upstream https://github.com/code-ready/crc.git
git fetch upstream
git rebase upstream/master
git push origin master --force



git checkout -b okd-snc

git checkout -b wip
<Make Code Changes>
git reset --soft okd-snc
git add .
git commit -m "Message Here"
git push
```

### CentOS 8 Nic issue:

```bash
ethtool -K nic0 tso off
```

### Market Place Disconnected

```bash
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/sources/0/disabled", "value": true}]'


# oc patch OperatorHub cluster --type json -p '[{"op": "remove", "path": "/spec/sources/0"}]'
# oc patch OperatorHub cluster --type json -p '[{"op": "replace", "path": "/spec/sources/0", "value": {"name":"community-operators","disabled":false}}]'
# oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/sources/-", "value": {"name":"community-operators","disabled":true}}]'
```

### Add worker node:

```bash
oc extract -n openshift-machine-api secret/worker-user-data --keys=userData --to=- > worker.ign
```