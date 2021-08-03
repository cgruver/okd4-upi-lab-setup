# This tutorial is being deprecated in favor of a new version:

## [OKD Home Lab](https://upstreamwithoutapaddle.com/home-lab/lab-intro/)

This repo will be Archived

# Installing OKD4.X with User Provisioned Infrastructure.

### Or, more precisely...  How to build your own desktop datacenter from scratch.

## I have written this guide from my own lab configuration.  So, it is opinionated toward a libvirt/KVM installation on CentOS Stream.

__If you want to connect with a team of OpenShift enthusiasts, join us in the OKD Working Group:__

https://github.com/openshift/okd

https://github.com/openshift/community

### If you create a fork of this project, you will want to re-sync with this repository periodically.  I am constantly fixing issues, refactoring, and adding new features.  Open an issue if you encounter problems.

__Read the [Tutorial on GitHub Pages](https://cgruver.github.io/okd4-upi-lab-setup/)__

Or, follow the directions in each section here:

1. [Building Your Lab](docs/index.md)
1. [Bastion Host](docs/pages/Bastion.md)
1. [DNS Setup](docs/pages/DNS_Config.md)
1. [Nginx Setup & RPM Repo sync](docs/pages/Nginx_Config.md)
1. [PXE Boot with TFTP & DHCP](docs/pages/GL-AR750S-Ext.md)
1. [Sonatype Nexus Setup](docs/pages/Nexus_Config.md)
1. [Build KVM Hosts](docs/pages/Deploy_KVM_Host.md)
1. [Deploy OKD](docs/pages/DeployOKD.md)

After deployment is complete, here are some things to do with your cluster:

1. [Designate your Master Nodes as Infrastructure Nodes](docs/pages/InfraNodes.md)

    __Do Not do this step if you do not have dedicated `worker` nodes.__

    If you have dedicated worker nodes in addition to three master nodes, then I recommend this step to pin your Ingress Routers to the Master nodes.  If they restart on worker nodes, you will lose Ingress access to your cluster unless you add the worker nodes to your external HA Proxy configuration.  I prefer to use Infrasturcture nodes to run the Ingress routers and a number of other pods.

1. [Set up Htpasswd as an Identity Provider](docs/pages/HtPasswd.md)
1. [Deploy a Ceph cluster for block storage provisioning](docs/pages/Ceph.md)
1. [Create a MariaDB Galera StatefulSet](docs/pages/MariaDB.md)
1. [Updating Your Cluster](docs/pages/UpdateOKD.md)
1. [Tekton pipeline for Quarkus and Spring Boot applications](https://github.com/cgruver/tekton-pipeline-okd4)
1. Coming soon...  
    1. Adding additional worker nodes
    1. Quarkus & Angular application to deploy with your new pipeline
1. [Gracefully shut down your cluster](docs/pages/ShuttingDown.md)
