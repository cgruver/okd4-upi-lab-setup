# Installing OKD4.X with User Provisioned Infrastructure.

## Note: Updated to support the OKD 4 GA release that just dropped.  FCOS made some changes to how network interfaces are configured.  This project is being updated to accomodate those changes.  The deployment script has been modified to inject NIC configuration into the ignition files for the OKD nodes.  The documentation will be updated soon.


## I have written this from my own lab configuration.

### Refactored for OKD 4.5 cluster with FCOS 32.  Still testing!  I will continue to push fixes and clarifications as I encounter issues.  Open issues if you encounter problems.  I am sure there are still plenty of bugs.  

__If you want to connect with a team of OpenShift enthusiasts, join us in the OKD Working Group:__

https://github.com/openshift/okd

https://github.com/openshift/community

### If you created a fork of this project, you will want to re-sync with this repository.  I am fixing issues while testing, and adding new features.  

Read the [Tutorial on GitHub Pages](https://cgruver.github.io/okd4-upi-lab-setup/)

Or, follow the directions in each section here:

1. [Building Your Lab](docs/index.md)
1. [Bastion Host](docs/pages/Bastion.md)
1. [DNS Setup](docs/pages/DNS_Config.md)
1. [Nginx Setup & RPM Repo sync](docs/pages/Nginx_Config.md)
1. [PXE Boot with TFTP & DHCP](docs/pages/DHCP.md)
1. [Sonatype Nexus Setup](docs/pages/Nexus_Config.md)
1. [Build KVM Hosts](docs/pages/Deploy_KVM_Host.md)
1. [Deploy OKD](docs/pages/DeployOKD.md)

After deployment is complete, here are some things to do with your cluster:

1. [Designate your Master Nodes as Infrastructure Nodes](InfraNodes.md)

    __Do Not do this step if you do not have dedicated `worker` nodes.__

    If you have dedicated worker nodes in addition to three master nodes, then I recommend this step to pin your Ingress Routers to the Master nodes.  If they restart on worker nodes, you will lose Ingress access to your cluster unless you add the worker nodes to your external HA Proxy configuration.  I prefer to use Infrasturcture nodes to run the Ingress routers and a number of other pods.

1. [Set up Htpasswd as an Identity Provider](docs/pages/HtPasswd.md)
1. [Deploy a Ceph cluster for block storage provisioning](docs/pages/Ceph.md)
1. [Create a MariaDB Galera StatefulSet](docs/pages/MariaDB.md)
1. [Updating Your Cluster](docs/pages/UpdateOKD.md)
1. Coming soon...  
    1. Adding additional worker nodes
    1. Tekton pipeline for Quarkus and Spring Boot applications
    1. Quarkus & Angular application to deploy with your new pipeline
1. [Gracefully shut down your cluster](docs/pages/ShuttingDown.md)
