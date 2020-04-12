### Building the MariaDB Galera Cluster container image

We are going to use docker to build this image.  Then we are going to push it to the image registry of our OpenShift cluster.

    mkdir -p ${OKD4_LAB_PATH}/mariadb
    cp -r ./MariaDB/* ${OKD4_LAB_PATH}/mariadb
    cd ${OKD4_LAB_PATH}/mariadb/Image
    ls -l

    total 40
    -rw-r--r--  1 user  staff  1231 Jan 12 12:33 Dockerfile
    -rw-r--r--  1 user  staff    98 Jan 12 12:30 MariaDB.repo
    -rw-r--r--  1 user  staff    87 Jan 12 12:26 liveness-probe.sh
    -rw-r--r--  1 user  staff  1999 Jan 12 12:37 mariadb-cluster.sh
    -rw-r--r--  1 user  staff    98 Jan 12 12:26 readiness-probe.sh

* `Dockerfile`: This file contains the directions for building our container.
* `MariaDB.repo`: This file is the definition for the MariaDB 10.4 RPM repository.  Since our container is based on a CentOS 7 base image, our package installer is RPM based.
* `liveness-probe.sh`: The script called by the OpenShift runtime to check pod liveness. More on this file and the next one later.  The liveness probe and readiness probe are used by OpenShift to monitor the state of the running container.
* `readiness-probe.sh`: The script called by the OpenShift runtime to check pod readiness.
* `mariadb-cluster.sh`: This is the main script that configures and starts MariaDB.  It is set as the entry point for the container image.


Now, let's build this image and push it to the OpenShift repository.  You need to know the URL of your OpenShift cluster image registry.  It will be something like:

    docker-registry-default.apps.your.cluster.domain.com

Where `apps.your.cluster.domain.com` is the wild-card DNS entry for your OpenShift cluster.

1. Make sure that your Docker daemon is running.

    On CentOS:

        systemctl start docker

    On a desktop OS, start `Docker Desktop`.

1. Log into your image registry: (Assuming that you are already logged into your OpenShift cluster)

        docker login -p $(oc whoami -t) -u admin docker-registry-default.apps.your.cluster.domain.com

1. Build the image:

        docker build -t docker-registry-default.apps.your.cluster.domain.com/openshift/mariadb-galera:10.4 .

1. Push the image to the OpenShift image registry.

        docker push docker-registry-default.apps.your.cluster.domain.com/openshift/mariadb-galera:10.4

Now, let's deploy a database cluster:

### Deploying a MariaDB Galera cluster into OpenShift:

Let's look at the OpenShift deployment files in the OKD-Deploy folder.

* `galera-iscsi-volumes.yaml`: Sample file for creating PersistentVolumes if you don't have a dynamic volume provider installed.
* `mariadb-galera-configmap.yaml`: ConfigMap with the MariaDB configuration
* `mariadb-galera-headless-svc.yaml`: Headless service for inter-pod communications
* `mariadb-galera-loadbalance-svc.yaml`: Service for database connections
* `mariadb-statefulset.yaml`: StatefulSet deployment definition

The OpenShift deployment is a StatefulSet.  A StatefulSet is a special kind of deployment that ensures that a given pod will always get the same PersistentVolumeClaim across restarts.  For more information, see the official documentation [here](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).

Before we deploy, you may have to modify `mariadb-statefulset.yaml` to reflect the type of PersistentVolume storage that you are using.  I have provided some examples below.  The file, as provided, will use your cluster's default storage provider which must be able to dynamically provision PersistentVolumes.

1. Using the default storage class (Assuming dynamic provisioning)

          ...
          volumeClaimTemplates:
            - metadata:
                name: data
              spec:
                resources:
                  requests:
                    storage: 50Gi
                accessModes: 
                  - ReadWriteOnce
          ... 

1. Using a dynamically provisioned storage class.  In this case, I have set up GlusterFS as both a block provisioner as well as an object store provisioner.  This example will request iSCSI mapped block devices from the `gluster-block` storage provisioner deployed into my OpenShift cluster.

          ...
          volumeClaimTemplates:
            - metadata:
                name: data
              spec:
                storageClassName: glusterfs-gfs-storage-block
                resources:
                  requests:
                    storage: 50Gi
                accessModes: 
                  - ReadWriteOnce
          ...

1. Using pre-configured PersistentVolumes associated with a non-provisioning storage class:

    Use this method in conjunction with the file: `galera-iscsi-volumes` which must be modified to match your storage configuration.  The example provided create a new storage class, `mariadb-sc`, and configures iSCSI attached persistent volumes.  I use a QNAP NAS-Book [TBS-453DX](https://www.qnap.com/en-us/product/tbs-453dx) to provide iSCSI luns to my home lab.  It requires manual configuration, but teaches you a lot about storage management.

          ...
          volumeClaimTemplates:
            - metadata:
                name: data
              spec:
                storageClassName: mariadb-sc
                resources:
                  requests:
                    storage: 50Gi
                accessModes: [ "ReadWriteOnce" ]
                selector:
                  matchLabels:
                    app: mariadb-galera
          ...

Now, let's deploy MariaDB: (Assuming that you are logged into your OpenShift cluster)

1. Create a new Namespace:

        oc new-project mariadb-galera

1. Create the service account for our MariaDB deployment, and add the `anyuid` Security Context Constraint to the service account.  This will allow the MariaDB pod to run as UID 27 like we defined in our Dockerfile.

        oc create sa mariadb -n mariadb-galera
        oc adm policy add-scc-to-user anyuid -z mariadb -n mariadb-galera

1. If you are using statically provisioned PersistentVolumes, deploy them now:

        oc apply -f galera-volumes.yaml 

1. Deploy the MariaDB cluster:

        oc apply -f mariadb-galera-configmap.yaml -n mariadb-galera
        oc apply -f mariadb-galera-headless-svc.yaml -n mariadb-galera
        oc apply -f mariadb-galera-loadbalance-svc.yaml -n mariadb-galera
        oc apply -f mariadb-statefulset.yaml -n mariadb-galera

You should now see your MariaDB cluster deploying.  Each node will start in series after the previous has passed it's readiness probe.  The `podManagementPolicy: "OrderedReady"` directive in the StatefulSet ensures that the cluster will always stop and start in a healthy state.

![Deployed Cluster](../images/Galera-Deployed.png)

### Next, we will [connect to our new cluster](UsingTheDatabase.md)
