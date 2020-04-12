# Notes before they become docs

Set Masters as Infra nodes

    for i in 0 1 2
    do
      oc label nodes okd4-master-${i}.${LAB_DOMAIN} node-role.kubernetes.io/infra=""
    done

    oc patch -n openshift-ingress-operator ingresscontroller default --patch '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}}}}}' --type=merge

    oc get pod -n openshift-ingress -o wide

    oc patch scheduler cluster --patch '{"spec":{"mastersSchedulable":false}}' --type=merge

Deploy Load Balancer

    DeployLabGuest.sh -h=okd4-prd-lb01 -n=bastion -r=lb-node -c=2 -m=4096 -d=50 -v=7000

Set up HTPasswd

    mkdir -p ${OKD4_LAB_PATH}/okd-creds
    ADMIN_PWD=$(cat ${OKD4_LAB_PATH}/okd4-install-dir/auth/kubeadmin-password)
    htpasswd -B -c -b ${OKD4_LAB_PATH}/okd-creds/htpasswd admin $(cat ${OKD4_LAB_PATH}/okd4-install-dir/auth/kubeadmin-password)
    htpasswd -b ${OKD4_LAB_PATH}/okd-creds/htpasswd devuser devpwd
    oc create -n openshift-config secret generic htpasswd-secret --from-file=htpasswd=${OKD4_LAB_PATH}/okd-creds/htpasswd
    oc apply -f ${OKD4_LAB_PATH}/htpasswd-cr.yml
    oc adm policy add-cluster-role-to-user cluster-admin admin

Remove temporary user:

    oc delete secrets kubeadmin -n kube-system

Expose Registry:

    oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
    docker login -u $(oc whoami) -p $(oc whoami -t) --tls-verify=false $(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')

Reset the HA Proxy configuration for a new cluster build:

    ssh okd4-lb01 "curl -o /etc/haproxy/haproxy.cfg http://${INSTALL_HOST_IP}/install/postinstall/haproxy.cfg && systemctl restart haproxy"
    
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
