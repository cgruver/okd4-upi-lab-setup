## Prepare to Install OKD 4.4

I have provided a set of utility scripts to automate a lot of the tasks associated with deploying and tearing down an OKD cluster.  In your `~/bin/lab-bin` directory you will see the following:

| | |
|-|-|
| `UnDeployLabGuest.sh` | Destroys a guest VM and supporting infrastructure |
| `DeployOkdNodes.sh` | Creates the HA-Proxy, Bootstrap, Master, and Worker VMs from an inventory file, (described below) |
| `UnDeployOkdNodes.sh` | Destroys the OKD cluster and all supporting infrastructure |
| `PowerOnVms.sh` | Helper script that uses IPMI to power on the VMs listed in an inventory file |

1. First, let's prepare to deploy the VMs for our OKD cluster by preparing the Cluster VM inventory file:

    This is not an ansible inventory like you might have encountered with OKD 3.11.  This is something I made up for my lab that allows me to quickly create, manage, and destroy virtual machines.

    I have provided an example that will create the virtual machines for this deployment.  It is located at `./Provisioning/guest_inventory/okd4_lab`.  The file is structured in such a way that it can be parsed by the utility scripts provided in this project.  The columns in the comma delimited file are used for the following purposes:

    | Column | Name | Description |
    |-|-|-|
    | 1 | KVM_HOST_NODE  | The hypervisor host that this VM will be provisioned on |
    | 2 | GUEST_HOSTNAME | The hostname of this VM, must be in DNS with `A` and `PTR` records |
    | 3 | MEMORY | The amount of RAM in MB to allocate to this VM |
    | 4 | CPU | The number of vCPUs to allocate to this VM |
    | 5 | ROOT_VOL | The size in GB of the first HDD to provision |
    | 6 | DATA_VOL | The size in GB of the second HDD to provision; `0` for none |
    | 7 | NUM_OF_NICS | The number of NICs to provision for thie VM; `1` or `2` |
    | 8 | ROLE | The OKD role that this VM will play: `ha-proxy`, `bootstrap`, `master`, or `worker` |
    | 9 | VBMC_PORT | The port that VBMC will bind to for IPMI control of this VM |

    It looks like this: (The entries for the three worker nodes are commented out, if you have two KVM hosts with 64GB RAM each, then you can uncomment those lines and have a full 6-node cluster)

    ```bash
    bastion,okd4-lb01,4096,1,50,0,1,ha-proxy,2668
    bastion,okd4-bootstrap,16384,4,50,0,1,bootstrap,6229
    kvm-host01,okd4-master-0,20480,4,100,0,1,master,6230
    kvm-host01,okd4-master-1,20480,4,100,0,1,master,6231
    kvm-host01,okd4-master-2,20480,4,100,0,1,master,6232
    # kvm-host02,okd4-worker-0,20480,4,100,0,1,worker,6233
    # kvm-host02,okd4-worker-1,20480,4,100,0,1,worker,6234
    # kvm-host02,okd4-worker-2,20480,4,100,0,1,worker,6235
    ```

    Copy this file into place, and modify it if necessary:

    ```bash
    mkdir -p ${OKD4_LAB_PATH}/guest-inventory
    cp ./Provisioning/guest_inventory/okd4_lab ${OKD4_LAB_PATH}/guest-inventory
    ```

1. Retrieve the `oc` command.  We're going to grab an older version of `oc`, but that's OK.  We just need it to retrieve to current versions of `oc` and `openshift-install`

    ```bash
    wget https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-07-14-153706-ga/openshift-client-linux-4.5.0-0.okd-2020-07-14-153706-ga.tar.gz
    ```

1. Uncompress the archive and move the `oc` executable to your ~/bin directory.  Make sure ~/bin is in your path.

    ```bash
    tar -xzf openshift-client-linux-4.5.0-0.okd-2020-07-14-153706-ga.tar.gz
    mv oc ~/bin
    ```

    The `DeployOkdNodes.sh` script will pull the correct version of `oc` and `openshift-install` when we run it.  It will over-write older versions in `~/bin`.

1. Now, we need a couple of pull secrets.  

   The first one is for quay.io.  Since we are installing OKD, we don't need an official pull secret.  So, we will use a fake one.

    1. Create the pull secret for Nexus.  Use a username and password that has write authority to the `origin` repository that we created earlier.

        ```bash
        NEXUS_PWD=$(echo -n "admin:your_admin_password" | base64 -w0)
        ```

    1. We need to put the pull secret into a JSON file that we will use to mirror the OKD images into our Nexus registry.  We'll also need the pull secret for our cluster install.

        ```bash
        cat << EOF > ${OKD4_LAB_PATH}/pull_secret.json
        {"auths": {"fake": {"auth": "Zm9vOmJhcgo="},"nexus.${LAB_DOMAIN}:5001": {"auth": "${NEXUS_PWD}"}}}
        EOF 
        ```

1. We need to pull a current version of OKD.  So point your browser at `https://origin-release.svc.ci.openshift.org`.  

    ![OKD Release](images/OKD-Release.png)

    Select the most recent 4.4.0-0.okd release that is in a Phase of `Accepted`, and copy the release name into an environment variable:

    ```bash
    export OKD_RELEASE=4.7.0-0.okd-2021-04-24-103438
    getOkdCmds.sh
    ```

1. The next step is to prepare our install-config.yaml file that `openshift-install` will use to create the `ignition` files for bootstrap, master, and worker nodes.

    I have prepared a skeleton file for you in this project, `./Provisioning/install-config-upi.yaml`.

    ```yaml
    apiVersion: v1
    baseDomain: %%LAB_DOMAIN%%
    metadata:
      name: %%CLUSTER_NAME%%
    networking:
      networkType: OpenShiftSDN
      clusterNetwork:
      - cidr: 10.100.0.0/14 
        hostPrefix: 23 
      serviceNetwork: 
      - 172.30.0.0/16
      machineNetwork:
      - cidr: 10.11.11.0/24
    compute:
    - name: worker
      replicas: 0
    controlPlane:
      name: master
      replicas: 3
    platform:
      none: {}
    pullSecret: '%%PULL_SECRET%%'
    sshKey: %%SSH_KEY%%
    additionalTrustBundle: |

    imageContentSources:
    - mirrors:
      - nexus.%%LAB_DOMAIN%%:5001/origin
      source: registry.svc.ci.openshift.org/origin/%%OKD_VER%%
    - mirrors:
      - nexus.%%LAB_DOMAIN%%:5001/origin
      source: registry.svc.ci.openshift.org/origin/release
    ```

    Copy this file to our working directory.

    ```bash
    cp ./Provisioning/install-config-upi.yaml ${OKD4_LAB_PATH}/install-config-upi.yaml
    ```

    Patch in some values:

    ```bash
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" ${OKD4_LAB_PATH}/install-config-upi.yaml
    SECRET=$(cat ${OKD4_LAB_PATH}/pull_secret.json)
    sed -i "s|%%PULL_SECRET%%|${SECRET}|g" ${OKD4_LAB_PATH}/install-config-upi.yaml
    SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
    sed -i "s|%%SSH_KEY%%|${SSH_KEY}|g" ${OKD4_LAB_PATH}/install-config-upi.yaml
    ```

    For the last piece, you need to manually paste in a cert.  No `sed` magic here for you...

    Copy the contents of: `/etc/pki/ca-trust/source/anchors/nexus.crt` and paste it into the blank line here in the config file:

    ```bash
    additionalTrustBundle: |

    imageContentSources:
    ```

    You need to indent every line of the cert with two spaces for the yaml syntax.

    Your install-config-upi.yaml file should now look something like:

    ```yaml
    apiVersion: v1
    baseDomain: your.domain.org
    metadata:
      name: %%CLUSTER_NAME%%
    networking:
      networkType: OpenShiftSDN
      clusterNetwork:
      - cidr: 10.100.0.0/14 
        hostPrefix: 23 
      serviceNetwork: 
      - 172.30.0.0/16
    compute:
    - name: worker
      replicas: 0
    controlPlane:
      name: master
      replicas: 3
    platform:
      none: {}
    pullSecret: '{"auths": {"fake": {"auth": "Zm9vOmJhcgo="},"nexus.oscluster.clgcom.org:5002": {"auth": "YREDACTEDREDACTED=="}}}'
    sshKey: ssh-rsa AAAREDACTEDREDACTEDAQAREDACTEDREDACTEDMnvPFqpEoOvZi+YK3L6MIGzVXbgo8SZREDACTEDREDACTEDbNZhieREDACTEDREDACTEDYI/upDR8TUREDACTEDREDACTEDoG1oJ+cRf6Z6gd+LZNE+jscnK/xnAyHfCBdhoyREDACTEDREDACTED9HmLRkbBkv5/2FPpc+bZ2xl9+I1BDr2uREDACTEDREDACTEDG7Ms0vJqrUhwb+o911tOJB3OWkREDACTEDREDACTEDU+1lNcFE44RREDACTEDREDACTEDov8tWSzn root@bastion
    additionalTrustBundle: |
      -----BEGIN CERTIFICATE-----
      MIIFyTREDACTEDREDACTEDm59lk0W1CnMA0GCSqGSIb3DQEBCwUAMHsxCzAJBgNV
      BAYTAlREDACTEDREDACTEDVTMREwDwYDVQQIDAhWaXJnaW5pYTEQMA4GA1UEBwwH
      A1UECgwGY2xnY29tMREwDwREDACTEDREDACTEDYDVQQLDAhva2Q0LWxhYjEjMCEG
      b3NjbHVzdGVyLmNsZ2NvbS5vcmcwHhcNMjAwMzREDACTEDREDACTEDE0MTYxMTQ2
      MTQ2WREDACTEDREDACTEDjB7MQswCQYDVQQGEwJVUzERMA8GA1UECAwIVmlyZ2lu
      B1JvYW5va2UxDzANBgNVBREDACTEDREDACTEDAoMBmNsZ2NvbTERMA8GA1UECwwI
      BgNVBAMMGm5leHVzLm9zY2x1c3Rlci5jbGdjbREDACTEDREDACTED20ub3JnMIIC
      REDACTEDREDACTEDAQEFAAOCAg8AMIICCgKCAgEAwwnvZEW+UqsyyWwHS4rlWbcz
      hmvMMBXEXqNqSp5sREDACTEDREDACTEDlYrjKIBdLa9isEfgIydtTWZugG1L1iA4
      hgdAlW83s8wwKW4bbEd8iDZyUFfzmFSKREDACTEDREDACTEDTrwk9JcH+S3/oGbk
      9iq8oKMiFkz9loYxTu93/p/iGieTWMFGajbAuUPjZsBYgbf9REDACTEDREDACTED
      REDACTEDREDACTEDYlFMcpkdlfYwJbJcfqeXAf9Y/QJQbBqRFxJCuXzr/D5Ingg3
      HrXXvOr612LWHFvZREDACTEDREDACTEDYj7JRKKPKXIA0NHA29Db0TdVUzDi3uUs
      WcDBmIpfZTXfrHG9pcj1CbOsw3vPhD4mREDACTEDREDACTEDCApsGKET4FhnFLkt
      yc2vpaut8X3Pjep821pQznT1sR6G1bF1eP84nFhL7qnBdhEwREDACTEDREDACTED
      REDACTEDREDACTEDIuOZH60cUhMNpl0uMSYU2BvfVDKQlcGPUh7pDWWhZ+5I1pei
      KgWUMBT/j3KAJNgFREDACTEDREDACTEDX43aDvUxyjbDg8FyjBGY1jdS8TnGg3YM
      zGP5auSqeyO1yZ2v3nbr9xUoRTVuzPUwREDACTEDREDACTED0SfiaeGPczpNfT8f
      6H0CAwEAAaNQME4wHQYDVR0OBBYEFPAJpXdtNX0bi8dh1QMsREDACTEDREDACTED
      REDACTEDREDACTEDIwQYMBaAFPAJpXdtNX0bi8dh1QMsE1URxd8tMAwGA1UdEwQF
      hvcNAQELBQADggIBREDACTEDREDACTEDAAx0CX20lQhP6HBNRl7C7IpTEBpds/4E
      dHuDuGMILaawZTbbKLMTlGu01Y8uCO/3REDACTEDREDACTEDUVZeX7X9NAw80l4J
      kPtLrp169L/09F+qc8c39jb7QaNRWenrNEFFJqoLRakdXM1MREDACTEDREDACTED
      REDACTEDREDACTED5CAWBCRgm67NhAJlzYOyqplLs0dPPX+kWdANotCfVxDx1jRM
      8tDL/7kurJA/wSOLREDACTEDREDACTEDDCaNs205/nEAEhrHLr8NHt42/TpmgRlg
      fcZ7JFw3gOtsk6Mi3XtS6rxSKpVqUWJ8REDACTEDREDACTED3nafC2IQCmBU2KIZ
      3Oir8xCyVjgf4EY/dQc5GpIxrJ3dV+U2Hna3ZsiCooAdq957REDACTEDREDACTED
      REDACTEDREDACTED57krXJy+4z8CdSMa36Pmc115nrN9Ea5C12d6UVnHnN+Kk4cL
      Wr9ZZSO3jDiwuzidREDACTEDREDACTEDk/IP3tkLtS0s9gWDdHdHeW0eit+trPib
      Oo9fJIxuD246HTQb+51ZfrvyBcbAA/M3REDACTEDREDACTED06B/Uq4CQMjhRwrU
      aUEYgiOJjUjLXGJSuDVdCo4J9kpQa5D1bUxcHxTp3R98CasnREDACTEDREDACTED
      -----END CERTIFICATE-----
    imageContentSources:
    - mirrors:
      - nexus.your.domain.org:5001/origin
      source: %%OKD_SOURCE_1%%
    - mirrors:
      - nexus.your.domain.org:5001/origin
      source: %%OKD_SOURCE_2%%
    ```

2. Now mirror the OKD images into the local Nexus:

    ```bash
    mirrorOkdRelease.sh
    ```

    The output should look something like:

    ```
    Success
    Update image:  nexus.your.domain.org:5001/origin:4.5.0-0.okd-2020-08-12-020541
    Mirror prefix: nexus.your.domain.org:5001/origin

    To use the new mirrored repository to install, add the following section to the install-config.yaml:

    imageContentSources:
    - mirrors:
      - nexus.your.domain.org:5001/origin
      source: quay.io/openshift/okd
    - mirrors:
      - nexus.your.domain.org:5001/origin
      source: quay.io/openshift/okd-content


    To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy:

    apiVersion: operator.openshift.io/v1alpha1
    kind: ImageContentSourcePolicy
    metadata:
      name: example
    spec:
      repositoryDigestMirrors:
      - mirrors:
        - nexus.your.domain.org:5001/origin
        source: quay.io/openshift/okd
      - mirrors:
        - nexus.your.domain.org:5001/origin
        source: quay.io/openshift/okd-content
    ```

1. Create a DNS sinkhole for `registry.svc.ci.openshift.org`, `quay.io`, `docker.io`, and `github.com`.  This will simulate a datacenter with no internet access.

    ```bash
    Sinkhole.sh -d
    ```

    __Note: When you want to restore access to the above domains, execute:

    ```bash
    Sinkhole.sh -c
    ```

3. Create the cluster virtual machines and set up for OKD installation:

    ```bash
    DeployOkdNodes.sh -i=${OKD4_LAB_PATH}/guest-inventory/okd4_lab -cn=okd4
    ```

    This script does a whole lot of work for us.

    1. It will pull the current versions of `oc` and `openshift-install` based on the value of `${OKD_RELEASE}` that we set previously.
    1. fills in the OKD version and `%%CLUSTER_NAME%%` in the install-config-upi.yaml file and copies that file to the install directory as install-config.yaml.
    1. Invokes the openshift-install command against our install-config to produce ignition files
    1. Copies the ignition files into place for FCOS install
    1. Sets up for a mirrored install by putting `quay.io` and `registry.svc.ci.openshift.org` into a DNS sinkhole.
    1. Creates guest VMs based on the inventory file at `${OKD4_LAB_PATH}/guest-inventory/okd4`
    1. Creates iPXE boot files for each VM and copies them to the iPXE server, (your router)

# We are now ready to fire up our OKD cluster!!!

1. Start the LB and watch the installation.

    ```bash
    ipmitool -I lanplus -H10.11.11.10 -p6228 -Uadmin -Ppassword chassis power on
    virsh console okd4-lb01
    ```

    You should see your HA Proxy VM do an iPXE boot and begin an unattended installation of CentOS 8.

1. Start the bootstrap node

    ```bash
    ipmitool -I lanplus -H10.11.11.10 -p6229 -Uadmin -Ppassword chassis power on
    ```

1. Start the cluster master nodes

    ```bash
    for i in 6230 6231 6232
    do
      ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on
    done
    ```

1. Start the cluster worker nodes (If you have any)

    ```bash
    for i in 6233 6234 6235
    do
      ipmitool -I lanplus -H10.11.11.10 -p${i} -Uadmin -Ppassword chassis power on
    done
    ```

### Now let's sit back and watch the install:

__Note: It is normal to see logs which look like errors while `bootkube` and `kublet` are waiting for resources to be provisioned.__

__Don't be alarmed if you see streams of `connection refused` errors for a minute or two.__  If the errors persist for more than a few minutes, then you might have real issues, but be patient.

* To watch a node boot and install:
  * Bootstrap node from the Bastion host:

      ```bash
      virsh console okd4-bootstrap
      ```

  * Master Node from `kvm-host01`

      ```bash
      virsh console okd4-master-0
      ```

* Once a host has installed FCOS:
  * Bootstrap Node:

      ```bash
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-bootstrap "journalctl -b -f -u bootkube.service"
      ```

  * Master Node:

      ```bash
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null core@okd4-master-0 "journalctl -b -f -u kubelet.service"
      ```

* Monitor OKD install progress:
  * Bootstrap Progress:

      ```bash
      openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir wait-for bootstrap-complete --log-level debug
      ```

  * When bootstrap is complete, remove the bootstrap node from HA-Proxy

      ```bash
      ssh root@okd4-lb01 "cat /etc/haproxy/haproxy.cfg | grep -v bootstrap > /etc/haproxy/haproxy.tmp && mv /etc/haproxy/haproxy.tmp /etc/haproxy/haproxy.cfg && systemctl restart haproxy.service"
      ```

    Destroy the Bootstrap Node on the Bastion host:

      ```bash
      DestroyBootstrap.sh
      ```

  * Install Progress:

      ```bash
      openshift-install --dir=${OKD4_LAB_PATH}/okd4-install-dir wait-for install-complete --log-level debug
      ```

* Install Complete:

    You will see output that looks like:

    ```bash
    INFO Waiting up to 10m0s for the openshift-console route to be created... 
    DEBUG Route found in openshift-console namespace: console 
    DEBUG Route found in openshift-console namespace: downloads 
    DEBUG OpenShift console route is created           
    INFO Install complete!                            
    INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/okd4-lab/okd4-install-dir/auth/kubeconfig' 
    INFO Access the OpenShift web-console here: https://console-openshift-console.apps.okd4.your.domain.org 
    INFO Login to the console with user: kubeadmin, password: aBCdE-FGHiJ-klMNO-PqrSt
    ```

### Log into your new cluster console:

Point your browser to the url listed at the completion of install: `https://console-openshift-console.apps.okd4.your.domain.org`

Log in as `kubeadmin` with the password from the output at the completion of the install.

__If you forget the password for this initial account, you can find it in the file:__ `${OKD4_LAB_PATH}/okd4-install-dir/auth/kubeadmin-password`

__Note: the first time you try to log in, you may have to wait a bit for all of the console resources to initialize.__

You will have to accept the certs for your new cluster.

### Issue commands against your new cluster:

```bash
export KUBECONFIG="${OKD4_LAB_PATH}/okd4-install-dir/auth/kubeconfig"
oc get pods --all-namespaces
```

You may need to approve the certs of you master and or worker nodes before they can join the cluster:

```bash
oc get csr
```

If you see certs in a Pending state:

```bash
oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
```

Create an Empty volume for registry storage:

```bash
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}}}}'
```

### If it all goes pancake shaped:

```bash
openshift-install --dir=okd4-install gather bootstrap --bootstrap 10.11.11.49 --master 10.11.11.60 --master 10.11.11.61 --master 10.11.11.62
```

### Next: 

1. Create an Image Pruner:

    ```bash
    oc patch imagepruners.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"schedule":"0 0 * * *","suspend":false,"keepTagRevisions":3,"keepYoungerThan":60,"resources":{},"affinity":{},"nodeSelector":{},"tolerations":[],"startingDeadlineSeconds":60,"successfulJobsHistoryLimit":3,"failedJobsHistoryLimit":3}}'
    ```
1. [Designate your Master Nodes as Infrastructure Nodes](InfraNodes.md)

    __Do Not do this step if you do not have dedicated `worker` nodes.__

    If you have dedicated worker nodes in addition to three master nodes, then I recommend this step to pin your Ingress Routers to the Master nodes.  If they restart on worker nodes, you will lose Ingress access to your cluster unless you add the worker nodes to your external HA Proxy configuration.  I prefer to use Infrasturcture nodes to run the Ingress routers and a number of other pods.

1. [Set up Htpasswd as an Identity Provider](HtPasswd.md)
1. [Deploy a Ceph cluster for block storage provisioning](Ceph.md)
1. [Create a MariaDB Galera StatefulSet](MariaDB.md)
1. [Updating Your Cluster](UpdateOKD.md)
1. Coming soon...  Tekton pipeline for Quarkus and Spring Boot applications.
1. [Gracefully shut down your cluster](ShuttingDown.md)
