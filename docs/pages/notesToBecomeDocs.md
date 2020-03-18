## Raw notes to become documentation:


### SSL for Sonatype Nexus:

```
openssl req -newkey rsa:4096 -nodes -sha256 -keyout nexus.key -x509 -days 5000 -out nexus.crt

# Country Name (2 letter code) [XX]:US
# State or Province Name (full name) []:Virginia
# Locality Name (eg, city) [Default City]:Roanoke
# Organization Name (eg, company) [Default Company Ltd]:yourCom
# Organizational Unit Name (eg, section) []:okd4-lab
# Common Name (eg, your name or your server's hostname) []:nexus.your.domain.org
# Email Address []:

openssl pkcs12 -export -in nexus.crt -inkey my.key -chain -CAfile nexus-ca-file.crt -name "your.domain.org" -out nexus.p12
openssl pkcs12 -export -in nexus.crt -inkey nexus.key -name "your.domain.org" -out nexus.p12
keytool -importkeystore -deststorepass password -destkeystore keystore.jks -srckeystore nexus.p12 -srcstoretype PKCS12

cp keystore.jks /usr/local/nexus/nexus-3/etc/ssl/keystore.jks
cp nexus.crt /etc/pki/ca-trust/source/anchors/nexus.crt
update-ca-trust



export OCP_RELEASE=4.4.0-0.okd-2020-03-13-191636
export LOCAL_REGISTRY=nexus.your.domain.org:5002
export LOCAL_REPOSITORY=origin
export PRODUCT_REPO=origin
export LOCAL_SECRET_JSON=${OKD4_LAB_PATH}/pull-secret.json
export RELEASE_NAME=release

registry.svc.ci.openshift.org/origin/release:4.4.0-0.okd-2020-03-11-174228

oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=registry.svc.ci.openshift.org/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}
```

Output:

```
Success
Update image:  nexus.your.domain.org:5002/origin:4.4.0-0.okd-2020-03-11-174228
Mirror prefix: nexus.your.domain.org:5002/origin

To use the new mirrored repository to install, add the following section to the install-config.yaml:

imageContentSources:
- mirrors:
  - nexus.your.domain.org:5002/origin
  source: registry.svc.ci.openshift.org/origin/4.4-2020-03-13-191636
- mirrors:
  - nexus.your.domain.org:5002/origin
  source: registry.svc.ci.openshift.org/origin/release


To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy:

apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: example
spec:
  repositoryDigestMirrors:
  - mirrors:
    - nexus.your.domain.org:5002/origin
    source: registry.svc.ci.openshift.org/origin/4.4-2020-03-13-191636
  - mirrors:
    - nexus.your.domain.org:5002/origin
    source: registry.svc.ci.openshift.org/origin/release
```

### Install-Config

```
apiVersion: v1
baseDomain: your.domain.org
metadata:
  name: okd4
networking:
  networkType: OpenShiftSDN
  clusterNetwork:
  - cidr: 10.100.0.0/14 
    hostPrefix: 23 
  serviceNetwork: 
  - 172.30.0.0/16
  machineNetwork:
  - cidr: 10.11.11.0/24
compute:
- name: worker
  replicas: 0
controlPlane:
  name: master
  replicas: 3
platform:
  none: {}
pullSecret: '{"auths": {"quay.io": {"auth": "Y2dydXZl-Redacted Password String", "email": ""},"nexus.your.domain.org:5002": {"auth": "YWR-Base64-Encoded-Credentials==", "email": ""}}}'
sshKey: ssh-rsa AAAAB3Nza-Your-Public-SSH-Key root@bastion
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  <Put the text from /etc/pki/ca-trust/source/anchors/nexus.crt here>
  -----END CERTIFICATE-----
imageContentSources:
  - mirrors:
    - nexus.your.domain.org:5002/origin
    source: registry.svc.ci.openshift.org/origin/4.4-2020-03-11-174228
  - mirrors:
    - nexus.your.domain.org:5002/origin
    source: registry.svc.ci.openshift.org/origin/release

```

## Install Cluster:

### FCOS

```
mkdir -p /usr/share/nginx/html/install/fcos/ignition
cd /usr/share/nginx/html/install/fcos

# https://getfedora.org/en/coreos/download/

curl -o vmlinuz https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200210.3.0/x86_64/fedora-coreos-31.20200210.3.0-live-kernel-x86_64
curl -o initrd https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200210.3.0/x86_64/fedora-coreos-31.20200210.3.0-live-initramfs.x86_64.img
curl -o install.xz https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200210.3.0/x86_64/fedora-coreos-31.20200210.3.0-metal.x86_64.raw.xz
curl -o install.xz.sig https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/31.20200210.3.0/x86_64/fedora-coreos-31.20200210.3.0-metal.x86_64.raw.xz.sig
```

### Start the LB

    ipmitool -I lanplus -H10.11.11.10 -p6228 -Uadmin -Ppassword chassis power on

### Start the bootstrap node

    ipmitool -I lanplus -H10.11.11.10 -p6229 -Uadmin -Ppassword chassis power on

### Start the cluster master nodes

    for i in 6230 6231 6232
    do
      ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on
    done

#### Start the cluster worker nodes

    for i in 6233 6234 6235
    do
      ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on
    done

## Monitor install:

```ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-bootstrap "journalctl -b -f -u bootkube.service"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-0 "journalctl -b -f -u kubelet.service"

openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir wait-for bootstrap-complete --log-level debug

openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir wait-for install-complete --log-level debug

export KUBECONFIG="${OKD4_LAB_PATH}/okd4-install-dir/auth/kubeconfig"
```

### Approve certs:

```
oc get csr

oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
```

### Empty vol for registry storage:

```
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}'
```

### iSCSI storage for registry:

```
cat << EOF > okd-infra-sc.yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ocp-infra-sc
provisioner: no-provisioning 
parameters: 
EOF

oc apply -f okd-infra-sc.yml

cat << EOF > okd-registry-pv.yml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: registry-pv
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 100Gi
  iscsi:
     targetPortal: 10.11.12.4:3260
     iqn: iqn.2004-04.com.qnap:tbs-453dx:iscsi.okd4registry01.3720be
     lun: 0
     fsType: 'xfs'
     readOnly: false
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ocp-infra-sc
EOF

cat << EOF > okd-registry-pvc.yml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  volumeName: registry-pv
  storageClassName: ocp-infra-sc
EOF

oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"persistentVolumeClaim":{"claimName":"registry-pvc"}}}}'
```

### If it all goes pancake shaped:

openshift-install --dir=okd4-install gather bootstrap --bootstrap 10.11.11.99 --master 10.11.11.101

