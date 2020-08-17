# KubeCon EU - OKD UPI Demo:

## Intro:

1. Mirrored Install
1. UPI
1. LB and VMs already staged
1. iPXE boot using MAC of primary NIC
1. Fixed IPs - added to ignition with fcct

## Bootstrap

Power On the Bootstrap Node:

    ipmitool -I lanplus -H10.11.11.10 -p6229 -Uadmin -Ppassword chassis power on

Watch it Boot:

    virsh console okd4-bootstrap

Start Master Nodes:

    for i in 6230 6231 6232; do   ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on; sleep 10; done

Watch Bootstrap logs:

    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-bootstrap.clg.lab "journalctl -b -f -u bootkube.service"

Monitor Bootstrap Progress:

    openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir wait-for bootstrap-complete --log-level debug

Remove Bootstrap Node:

    ssh root@okd4-lb01.clg.lab "cat /etc/haproxy/haproxy.cfg | grep -v bootstrap > /etc/haproxy/haproxy.tmp && mv /etc/haproxy/haproxy.tmp /etc/haproxy/haproxy.cfg && systemctl restart haproxy.service"

    virsh destroy okd4-bootstrap

## Complete Install

Monitor Install Progress:

    openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir wait-for install-complete --log-level debug

## Discuss the environment while install completes:

### Load Balancer Configuration

    ssh root@okd4-lb01.clg.lab "cat /etc/haproxy/haproxy.cfg"

### DNS

    cat /etc/named/zones/db.clg.lab

### iPXE



## Post Install

    export KUBECONFIG="${OKD4_LAB_PATH}/okd4-install-dir/auth/kubeconfig"

Remove Samples Operator:

    oc patch configs.samples.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Removed"}}'

EmptyDir for Registry:

    oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}'

Image Pruner:

    oc patch imagepruners.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"schedule":"0 0 * * *","suspend":false,"keepTagRevisions":3,"keepYoungerThan":60,"resources":{},"affinity":{},"nodeSelector":{},"tolerations":[],"startingDeadlineSeconds":60,"successfulJobsHistoryLimit":3,"failedJobsHistoryLimit":3}}'

Add Worker Nodes:

    for i in 6233 6234 6235; do   ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on; sleep 10; done

Monitor Worker Node Boot:

    ssh root@kvm-host01.clg.lab
    virsh console okd4-worker-0

Approve CSR:

    oc get csr
    oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve

    oc get nodes

Designate Infra Nodes:

    for i in 0 1 2
    do
        oc label nodes okd4-master-${i}.${LAB_DOMAIN} node-role.kubernetes.io/infra=""
    done

    oc patch scheduler cluster --patch '{"spec":{"mastersSchedulable":false}}' --type=merge

    oc patch -n openshift-ingress-operator ingresscontroller default --patch '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}},"tolerations":[{"key":"node.kubernetes.io/unschedulable","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","effect":"NoSchedule"}]}}}' --type=merge

    oc get pod -n openshift-ingress -o wide

HtPassword Setup:

    oc create -n openshift-config secret generic htpasswd-secret --from-file=htpasswd=${OKD4_LAB_PATH}/okd-creds/htpasswd

    oc apply -f ./Provisioning/htpasswd-cr.yaml
    
    oc adm policy add-cluster-role-to-user cluster-admin admin
    
    oc delete secrets kubeadmin -n kube-system

## Open DNS for Updates:

    ssh root@${LAB_NAMESERVER} 'sed -i "s|registry.svc.ci.openshift.org|;sinkhole-reg|g" /etc/named/zones/db.sinkhole && sed -i "s|quay.io|;sinkhole-quay|g" /etc/named/zones/db.sinkhole && systemctl restart named'

## Ceph

       for i in 0 1 2
       do
         oc label nodes okd4-worker-${i}.${LAB_DOMAIN} role=storage-node
       done

       oc apply -f ${OKD4_LAB_PATH}/ceph/common.yml
       oc apply -f ${OKD4_LAB_PATH}/ceph/operator-openshift.yml

       oc apply -f ${OKD4_LAB_PATH}/ceph/cluster.yml

       oc get pods -n rook-ceph

## PVC for the Image Registry

    oc apply -f ${OKD4_LAB_PATH}/ceph/ceph-storage-class.yml

    oc apply -f ${OKD4_LAB_PATH}/ceph/registry-pvc.yml

    oc get pvc -n openshift-image-registry
    
    oc patch configs.imageregistry.operator.openshift.io cluster --type json -p '[{ "op": "remove", "path": "/spec/storage/emptyDir" }]'

    oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"rolloutStrategy":"Recreate","managementState":"Managed","storage":{"pvc":{"claim":"registry-pvc"}}}}'

## Eclipse Che