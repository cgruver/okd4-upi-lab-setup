# Notes before they become docs

Reset the HA Proxy configuration for a new cluster build:

    ssh okd4-lb01 "curl -o /etc/haproxy/haproxy.cfg http://${INSTALL_HOST}/install/postinstall/haproxy.cfg && systemctl restart haproxy"
    
Upgrade:

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

Samples Operator: Extract templates and image streams, then remove the operator.  We don't want everything and the kitchen sink...

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

Fix Hostname:

    for i in 0 1 2 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-${i}.${LAB_DOMAIN} "sudo hostnamectl set-hostname okd4-master-${i}.my.domain.org && sudo shutdown -r now"; done
    for i in 0 1 2 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-worker-${i}.${LAB_DOMAIN} "sudo hostnamectl set-hostname okd4-worker-${i}.my.domain.org && sudo shutdown -r now"; done

Logs:

    for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-${i}.${LAB_DOMAIN} "sudo journalctl --disk-usage"; done
    for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-worker-${i}.${LAB_DOMAIN} "sudo journalctl --disk-usage"; done

    for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-${i}.${LAB_DOMAIN} "sudo journalctl --vacuum-time=1s"; done
    for i in 0 1 2 ; do echo "okd4-master-${i}" ; ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-worker-${i}.${LAB_DOMAIN} "sudo journalctl --vacuum-time=1s"; done

Project Provisioning:

    oc describe clusterrolebinding.rbac self-provisioners

    # Remove self-provisioning from all roles
    oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'

    # Remove from specific role
    oc adm policy remove-cluster-role-from-group self-provisioner system:authenticated:oauth

    # Prevent automatic updates to the role
    oc patch clusterrolebinding.rbac self-provisioners -p '{ "metadata": { "annotations": { "rbac.authorization.kubernetes.io/autoupdate": "false" } } }'

iSCSI:

    echo "InitiatorName=iqn.$(hostname)" > /etc/iscsi/initiatorname.iscsi
    systemctl enable iscsid --now

    iscsiadm -m  discovery -t st -l -p 10.11.11.5:3260

    for i in 0 1 2 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-prd-master-${i}.${LAB_DOMAIN} "sudo bash -c \"echo InitiatorName=iqn.$(hostname) > /etc/iscsi/initiatorname.iscsi\" && sudo systemctl enable iscsid --now"; done

    for i in 0 1 2 3 4 5 ; do ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-prd-worker-${i}.${LAB_DOMAIN} "sudo bash -c \"echo InitiatorName=iqn.$(hostname) > /etc/iscsi/initiatorname.iscsi\" && sudo systemctl enable iscsid --now"; done

FCCT:

    wget https://github.com/coreos/fcct/releases/download/v0.6.0/fcct-x86_64-unknown-linux-gnu
    mv fcct-x86_64-unknown-linux-gnu ~/bin/lab_bin/fcct 
    chmod 750 ~/bin/lab_bin/fcct

```
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
