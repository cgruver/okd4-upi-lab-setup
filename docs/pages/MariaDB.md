# Deploying a MariaDB Galera Cluster

__Note: This section assumes that you have set up Ceph storage as described here: [Ceph](Ceph.md)__

In this section we will build a custom container image that is configured to be part of a MariaDB 10.4 cluster using Galera.  The MariaSB cluster will be deployed as a StatefulSet and will leverage Ceph block devices with an XFS filesystem for persistent storage.

### Building the MariaDB Galera Cluster container image

We are going to use podman to build this image.  Then, we are going to push it to the image registry of our OpenShift cluster.

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


Now, let's build this image and push it to the OpenShift repository.

1. Make sure that your Docker daemon is running.

    On CentOS:

        systemctl start docker

    On a desktop OS, start `Docker Desktop`.

2. Log into your image registry: (Assuming that you are already logged into your OpenShift cluster)

    If you have not exposed the default route for external access to the registry, do that now:
    
       oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
    
    Log in:
    
       podman login -u $(oc whoami) -p $(oc whoami -t) --tls-verify=false $(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')

3. Build the image:

        podman build -t $(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')/openshift/mariadb-galera:10.4 .

4. Push the image to the OpenShift image registry.

        podman push $(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')/openshift/mariadb-galera:10.4 --tls-verify=false

Now, let's deploy a database cluster:

    cd ../Deploy

### Deploying a MariaDB Galera cluster into OpenShift:

Let's look at the OpenShift deployment files in the Deploy folder.

* `mariadb-galera-configmap.yaml`: ConfigMap with the MariaDB configuration
* `mariadb-galera-headless-svc.yaml`: Headless service for inter-pod communications
* `mariadb-galera-loadbalance-svc.yaml`: Service for database connections
* `mariadb-statefulset.yaml`: StatefulSet deployment definition

The OpenShift deployment is a StatefulSet.  A StatefulSet is a special kind of deployment that ensures that a given pod will always get the same PersistentVolumeClaim across restarts.  For more information, see the official documentation [here](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).

Now, let's deploy MariaDB: (Assuming that you are logged into your OpenShift cluster)

1. Create a new Namespace:

        oc new-project mariadb-galera

1. Create the service account for our MariaDB deployment, and add the `anyuid` Security Context Constraint to the service account.  This will allow the MariaDB pod to run as UID 27 like we defined in our Dockerfile.

        oc create sa mariadb -n mariadb-galera
        oc adm policy add-scc-to-user anyuid -z mariadb -n mariadb-galera

1. Deploy the MariaDB cluster:

        oc apply -f mariadb-galera-configmap.yaml -n mariadb-galera
        oc apply -f mariadb-galera-headless-svc.yaml -n mariadb-galera
        oc apply -f mariadb-galera-loadbalance-svc.yaml -n mariadb-galera
        oc apply -f mariadb-statefulset.yaml -n mariadb-galera

You should now see your MariaDB cluster deploying.  Each node will start in series after the previous has passed it's readiness probe.  The `podManagementPolicy: "OrderedReady"` directive in the StatefulSet ensures that the cluster will always stop and start in a healthy state.
