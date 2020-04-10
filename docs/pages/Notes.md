# Notes before they become docs

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


I0410 17:43:28.176079       1 verify.go:298] Unable to verify sha256:ce16ac845c0a0d178149553a51214367f63860aea71c0337f25556f25e5b8bb3 against keyring verifier-public-key-openshift-ci
W0410 17:43:28.176238       1 updatepayload.go:100] An image was retrieved from "registry.svc.ci.openshift.org/origin/release@sha256:ce16ac845c0a0d178149553a51214367f63860aea71c0337f25556f25e5b8bb3" that failed verification: The update cannot be verified: unable to locate a valid signature for one or more sources
I0410 17:43:33.738230       1 reflector.go:241] github.com/openshift/client-go/config/informers/externalversions/factory.go:101: forcing resync
I0410 17:43:34.232890       1 payload.go:210] Loading updatepayload from "/etc/cvo/updatepayloads/5pL6NjLbVlPJTzWB8LXg5A"
I0410 17:43:34.739689       1 sync_worker.go:539] Payload loaded from registry.svc.ci.openshift.org/origin/release@sha256:ce16ac845c0a0d178149553a51214367f63860aea71c0337f25556f25e5b8bb3 with hash Vv8IiP1yXeE=
I0410 17:43:34.741608       1 task_graph.go:586] Waiting for workers to complete
I0410 17:43:34.741606       1 task_graph.go:575] Running 0 on 7
I0410 17:43:34.741713       1 task_graph.go:575] Running 1 on 11
I0410 17:43:34.741751       1 sync_worker.go:621] Running sync for namespace "openshift-cluster-version" (1 of 574)
I0410 17:43:34.746778       1 sync_worker.go:634] Done syncing for namespace "openshift-cluster-version" (1 of 574)
I0410 17:43:34.746912       1 sync_worker.go:621] Running sync for customresourcedefinition "clusteroperators.config.openshift.io" (2 of 574)
I0410 17:43:34.752351       1 sync_worker.go:634] Done syncing for customresourcedefinition "clusteroperators.config.openshift.io" (2 of 574)
I0410 17:43:34.752514       1 sync_worker.go:621] Running sync for customresourcedefinition "clusterversions.config.openshift.io" (3 of 574)
I0410 17:43:34.759965       1 sync_worker.go:634] Done syncing for customresourcedefinition "clusterversions.config.openshift.io" (3 of 574)
I0410 17:43:34.760017       1 sync_worker.go:621] Running sync for clusterrolebinding "cluster-version-operator" (4 of 574)
I0410 17:43:34.771712       1 sync_worker.go:634] Done syncing for clusterrolebinding "cluster-version-operator" (4 of 574)
I0410 17:43:34.771800       1 sync_worker.go:621] Running sync for deployment "openshift-cluster-version/cluster-version-operator" (5 of 574)
I0410 17:43:34.847898       1 start.go:140] Shutting down due to terminated
I0410 17:43:34.847980       1 start.go:188] Stepping down as leader
I0410 17:43:34.847998       1 task_graph.go:568] Canceled worker 8
E0410 17:43:34.848037       1 task.go:81] error running apply for deployment "openshift-cluster-version/cluster-version-operator" (5 of 574): deployment openshift-cluster-version/cluster-version-operator is progressing NewReplicaSetAvailable: ReplicaSet "cluster-version-operator-5657d5967" has successfully progressed.
I0410 17:43:34.848077       1 task_graph.go:568] Canceled worker 11
I0410 17:43:34.848082       1 task_graph.go:568] Canceled worker 14
I0410 17:43:34.848095       1 task_graph.go:568] Canceled worker 5
I0410 17:43:34.848098       1 task_graph.go:568] Canceled worker 7
I0410 17:43:34.848106       1 task_graph.go:568] Canceled worker 2
I0410 17:43:34.848126       1 task_graph.go:568] Canceled worker 1
I0410 17:43:34.848140       1 task_graph.go:568] Canceled worker 0
I0410 17:43:34.848152       1 task_graph.go:568] Canceled worker 3
I0410 17:43:34.848161       1 task_graph.go:568] Canceled worker 10
I0410 17:43:34.848170       1 task_graph.go:568] Canceled worker 9
I0410 17:43:34.848204       1 task_graph.go:516] No more reachable nodes in graph, continue
I0410 17:43:34.848212       1 task_graph.go:552] No more work
I0410 17:43:34.848224       1 task_graph.go:572] No more work for 13
I0410 17:43:34.848235       1 task_graph.go:568] Canceled worker 12
I0410 17:43:34.848254       1 task_graph.go:572] No more work for 6
I0410 17:43:34.848251       1 cvo.go:439] Started syncing cluster version "openshift-cluster-version/version" (2020-04-10 17:43:34.848246915 +0000 UTC m=+1488.153100869)
I0410 17:43:34.848321       1 cvo.go:468] Desired version from spec is v1.Update{Version:"4.4.0-0.okd-2020-04-09-124138", Image:"registry.svc.ci.openshift.org/origin/release@sha256:ce16ac845c0a0d178149553a51214367f63860aea71c0337f25556f25e5b8bb3", Force:true}
I0410 17:43:34.848643       1 task_graph.go:568] Canceled worker 15
I0410 17:43:34.848672       1 task_graph.go:568] Canceled worker 4
I0410 17:43:34.848699       1 task_graph.go:588] Workers finished
I0410 17:43:34.848713       1 task_graph.go:596] Result of work: [deployment openshift-cluster-version/cluster-version-operator is progressing NewReplicaSetAvailable: ReplicaSet "cluster-version-operator-5657d5967" has successfully progressed.]
I0410 17:43:34.848732       1 sync_worker.go:783] Summarizing 1 errors
I0410 17:43:34.848738       1 sync_worker.go:787] Update error 5 of 574: WorkloadNotAvailable deployment openshift-cluster-version/cluster-version-operator is progressing NewReplicaSetAvailable: ReplicaSet "cluster-version-operator-5657d5967" has successfully progressed. (*errors.errorString: deployment openshift-cluster-version/cluster-version-operator is progressing; updated replicas=1 of 1, available replicas=1 of 1)
E0410 17:43:34.848787       1 sync_worker.go:329] unable to synchronize image (waiting 2m52.525702462s): deployment openshift-cluster-version/cluster-version-operator is progressing NewReplicaSetAvailable: ReplicaSet "cluster-version-operator-5657d5967" has successfully progressed.
I0410 17:43:34.870011       1 cvo.go:441] Finished syncing cluster version "openshift-cluster-version/version" (21.754847ms)
I0410 17:43:34.870066       1 cvo.go:366] Shutting down ClusterVersionOperator
I0410 17:43:34.982922       1 start.go:199] Finished shutdown

*****

I0410 17:46:03.295513       1 start.go:19] ClusterVersionOperator v1.0.0-196-g23856901-dirty
I0410 17:46:03.296029       1 merged_client_builder.go:122] Using in-cluster configuration
I0410 17:46:03.325834       1 payload.go:210] Loading updatepayload from "/"
I0410 17:46:04.065344       1 cvo.go:264] Verifying release authenticity: All release image digests must have GPG signatures from verifier-public-key-openshift-ci (D04761B116203B0C0859B61628B76E05B923888E: openshift-ci) - will check for signatures in containers/image format at https://storage.googleapis.com/openshift-release/test-1/signatures/openshift/release and from config maps in openshift-config-managed with label "release.openshift.io/verification-signatures"
I0410 17:46:04.066110       1 leaderelection.go:241] attempting to acquire leader lease  openshift-cluster-version/version...
E0410 17:46:04.066949       1 leaderelection.go:330] error retrieving resource lock openshift-cluster-version/version: Get https://127.0.0.1:6443/api/v1/namespaces/openshift-cluster-version/configmaps/version: dial tcp 127.0.0.1:6443: connect: connection refused
I0410 17:46:04.067031       1 leaderelection.go:246] failed to acquire lease openshift-cluster-version/version
I0410 17:46:49.376093       1 leaderelection.go:350] lock is held by okd4-master-0.oscluster.clgcom.org_2a997ee2-7f32-4908-9440-1dfba3ca357b and has not yet expired
I0410 17:46:49.376115       1 leaderelection.go:246] failed to acquire lease openshift-cluster-version/version
I0410 17:47:44.106799       1 leaderelection.go:350] lock is held by okd4-master-0.oscluster.clgcom.org_2a997ee2-7f32-4908-9440-1dfba3ca357b and has not yet expired
I0410 17:47:44.106819       1 leaderelection.go:246] failed to acquire lease openshift-cluster-version/version
I0410 17:48:16.473384       1 leaderelection.go:350] lock is held by okd4-master-0.oscluster.clgcom.org_2a997ee2-7f32-4908-9440-1dfba3ca357b and has not yet expired
I0410 17:48:16.473407       1 leaderelection.go:246] failed to acquire lease openshift-cluster-version/version
