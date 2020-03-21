
# Documentation is still WIP

# ToDo: Deploy load balancer VM

# ToDo: Describe Deployment Scripts

# ToDo: Explain OKD Deployment

export OKD_RELEASE=4.4.0-0.okd-2020-03-13-191636

oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=registry.svc.ci.openshift.org/${PRODUCT_REPO}/${RELEASE_NAME}:${OKD_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OKD_RELEASE}

DeployOkdNodes.sh -i=/root/okd4-lab/guest-inventory/okd4 -p -m

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
### If it all goes pancake shaped:

openshift-install --dir=okd4-install gather bootstrap --bootstrap 10.11.11.99 --master 10.11.11.101
