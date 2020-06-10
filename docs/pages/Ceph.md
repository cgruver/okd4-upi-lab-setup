## Hyper-Converged Ceph Cluster Deployment

The following instructions will set up Ceph storage as a block provider for your OKD cluster.  You will then create a PVC for the OKD image registry, and modify the image registry to use the PVC for persistence.

Ideally, you need a full cluster for this deployment; 3 master and 3 worker nodes.  Additionally, you need to give the worker nodes a second disk that will be used by Ceph.  I have provided an example guest_inventory file at `./Provisioning/guest_inventory/okd4_ceph`.  You can do this with a minimal cluster of just 3 master/worker nodes, but you may need to add RAM to avoid constraints.

Follow these steps to deploy a Ceph cluster:

1. From the root directory of this project, grab and modify the files that are prepared for you.

       mkdir -p ${OKD4_LAB_PATH}/ceph
       cp ./Ceph/* ${OKD4_LAB_PATH}/ceph
       sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" ${OKD4_LAB_PATH}/ceph/cluster.yml

    The Ceph installation files were taken from https://github.com/rook/rook and modified for this tutorial.

    __Note: If you do not have worker nodes, then you will need to modify the `cluster.yml` file to use your master nodes.__

1. Now, we need to label our worker nodes so that Ceph knows where to deploy.  If you look at the cluster.yml file, you will see the `nodeAffinity` configuration.

    __Note: As before, if you do not have dedicated worker nodes, then replace `worker` with `master` below.__

       for i in 0 1 2
       do
         oc label nodes okd4-worker-${i}.${LAB_DOMAIN} role=storage-node
       done

1. Create the Ceph Operator:

       oc apply -f ${OKD4_LAB_PATH}/ceph/common.yml
       oc apply -f ${OKD4_LAB_PATH}/ceph/operator-openshift.yml

    __Wait for the Operator pods to completely deploy before executing the next step.__

1. Deploy the Ceph cluster:

       oc apply -f ${OKD4_LAB_PATH}/ceph/cluster.yml

    __This will take a while to complete.__  
    
    It is finished when you see all of the `rook-ceph-osd-prepare-okd4-worker...` pods in a `Completed` state.

       oc get pods -n rook-ceph

### Now, let's create a PVC for the Image Registry.

1. First, we need a Storage Class for our new Ceph block strage provisioner:

       oc apply -f ${OKD4_LAB_PATH}/ceph/ceph-storage-class.yml

1. Now create the PVC:

       oc apply -f ${OKD4_LAB_PATH}/ceph/registry-pvc.yml

1. Make sure that the PVC gets bound to a new PV:

       oc get pvc -n openshift-image-registry

    You should see output similar to:

       NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
       registry-pvc   Bound    pvc-bcee4ccd-aa6e-4c8c-89b0-3f8da1c17df0   100Gi      RWO            rook-ceph-block   4d17h

1. Finally, patch the `imageregistry` operator to use the PVC that you just created:

    If you previously added `emptyDir` as a storage type to the Registry, you need to remove it first:
       
       oc patch configs.imageregistry.operator.openshift.io cluster --type json -p '[{ "op": "remove", "path": "/spec/storage/emptyDir" }]'
       
    Now patch it to use the new PVC:
    
       oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"rolloutStrategy":"Recreate","managementState":"Managed","storage":{"pvc":{"claim":"registry-pvc"}}}}'

__You just created a Ceph cluster and bound your image registry to a Persistent Volume!__
