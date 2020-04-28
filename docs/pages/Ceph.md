## Ceph setup WIP

    mkdir -p ${OKD4_LAB_PATH}/ceph
    cp ./Provisioning/Ceph/* ${OKD4_LAB_PATH}/ceph
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" ${OKD4_LAB_PATH}/ceph/cluster.yml

    for i in 0 1 2
    do
      oc label nodes okd4-worker-${i}.${LAB_DOMAIN} role=storage-node
    done

    oc apply -f ${OKD4_LAB_PATH}/ceph/common.yml
    oc apply -f ${OKD4_LAB_PATH}/ceph/operator-openshift.yml
    oc apply -f ${OKD4_LAB_PATH}/ceph/cluster.yml
    oc apply -f ${OKD4_LAB_PATH}/ceph/ceph-storage-class.yml
    oc apply -f ${OKD4_LAB_PATH}/ceph/registry-pvc.yml

    oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"rolloutStrategy":"Recreate","managementState":"Managed","storage":{"pvc":{"claim":"registry-pvc"}}}}'
