# Safely Shutting Down Your OKD Cluster

# WIP: Documentation Incomplete

Sccale down any applications using your MariaDB RDBMS

Scale down the MariaDB cluster

    oc scale statefulsets mariadb-galera --replicas=0 -n  mariadb-galera

    oc get pods -n  mariadb-galera 

    NAME               READY   STATUS        RESTARTS   AGE
    mariadb-galera-0   1/1     Running       0          13m
    mariadb-galera-1   1/1     Running       0          12m
    mariadb-galera-2   1/1     Terminating   0          12m

Be patient and wait for all 3 pods to shutdown.

    oc get pods -n  mariadb-galera

    NAME               READY   STATUS        RESTARTS   AGE
    mariadb-galera-0   1/1     Running       0          14m
    mariadb-galera-1   1/1     Terminating   0          14m

    oc get pods -n  mariadb-galera

    NAME               READY   STATUS        RESTARTS   AGE
    mariadb-galera-0   1/1     Terminating   0          15m

Shutdown the Image Registry:

    oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Removed"}}'

Cordon, and Drain the `worker` nodes:  (This will take a while, be patient)

    for i in 0 1 2 ; do oc adm cordon okd4-worker-${i}.${LAB_DOMAIN} ; done

    for i in 0 1 2 ; do oc adm drain okd4-worker-${i}.${LAB_DOMAIN} --ignore-daemonsets --force --grace-period=60 --delete-local-data &; done

Shutdown the worker nodes: (Wait for them to all shut down before proceeding)

    for i in 0 1 2 ; do ssh core@okd4-worker-${i}.${LAB_DOMAIN} "sudo shutdown -h now"; done

Shutdown the master nodes: (Wait for them to all shut down before proceeding)

    for i in 0 1 2 ; do ssh core@okd4-master-${i}.${LAB_DOMAIN} "sudo shutdown -h now"; done

Shutdown the load balancer:

    ssh root@okd4-lb01 "shutdown -h now"



### Restarting after shutdown:

    ipmitool -I lanplus -H10.11.11.10 -p6228 -Uadmin -Ppassword chassis power on

    for i in 6230 6231 6232; do   ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on; sleep 3; done

    ssh core@okd4-master-0.${LAB_DOMAIN} "journalctl -b -f -u kubelet.service"
    
    oc login -u admin  https://api.okd4.${LAB_DOMAIN}:6443

    oc get nodes

    NAME                                 STATUS                        ROLES          AGE   VERSION
    okd4-master-0.your.domain.org   Ready                         infra,master   21d   v1.17.1
    okd4-master-1.your.domain.org   Ready                         infra,master   21d   v1.17.1
    okd4-master-2.your.domain.org   Ready                         infra,master   21d   v1.17.1
    okd4-worker-0.your.domain.org   NotReady,SchedulingDisabled   worker         21d   v1.17.1
    okd4-worker-1.your.domain.org   NotReady,SchedulingDisabled   worker         21d   v1.17.1
    okd4-worker-2.your.domain.org   NotReady,SchedulingDisabled   worker         21d   v1.17.1

    for i in 6233 6234 6235; do   ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on; sleep 3; done

    oc get nodes

    NAME                                 STATUS                     ROLES          AGE   VERSION
    okd4-master-0.your.domain.org   Ready                      infra,master   21d   v1.17.1
    okd4-master-1.your.domain.org   Ready                      infra,master   21d   v1.17.1
    okd4-master-2.your.domain.org   Ready                      infra,master   21d   v1.17.1
    okd4-worker-0.your.domain.org   Ready,SchedulingDisabled   worker         21d   v1.17.1
    okd4-worker-1.your.domain.org   Ready,SchedulingDisabled   worker         21d   v1.17.1
    okd4-worker-2.your.domain.org   Ready,SchedulingDisabled   worker         21d   v1.17.1

    oc get nodes

    NAME                                 STATUS   ROLES          AGE   VERSION
    okd4-master-0.your.domain.org   Ready    infra,master   21d   v1.17.1
    okd4-master-1.your.domain.org   Ready    infra,master   21d   v1.17.1
    okd4-master-2.your.domain.org   Ready    infra,master   21d   v1.17.1
    okd4-worker-0.your.domain.org   Ready    worker         21d   v1.17.1
    okd4-worker-1.your.domain.org   Ready    worker         21d   v1.17.1
    okd4-worker-2.your.domain.org   Ready    worker         21d   v1.17.1


    for i in 0 1 2 ; do oc adm uncordon okd4-worker-${i}.${LAB_DOMAIN} ; done

    oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'

    oc scale statefulsets mariadb-galera --replicas=3 -n  mariadb-galera 
