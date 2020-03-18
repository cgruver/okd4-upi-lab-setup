## Setting up the Bastion host

The bastion host is generically what I call the system that hosts utilities in support of the rest of the lab.  It is also configured for password-less SSH into the rest of the lab.

The bastion host serves:

* Nginx for hosting RPMs and install files for KVM hosts and guests.
* A DNS server for the lab ecosystem.
* Sonatype Nexus for the OKD registry mirror, Maven Artifacts, and Container Images.

I recommend using a bare-metal host for your Bastion.  It will also run the load-balancer VM and Bootstrap VM for your cluster.  I am using a [NUC8i3BEK](https://ark.intel.com/content/www/us/en/ark/products/126149/intel-nuc-kit-nuc8i3bek.html) with 32GB of RAM for my Bastion host. The little box with 32GB of RAM is perfect for this purpose, and also very portable for throwing in a bag to take my dev environment with me.  My OpenShift build environment is also installed on the Bastion host.

You need to start with a minimal CentOS 7 install.

    wget https://buildlogs.centos.org/rolling/7/isos/x86_64/CentOS-7-x86_64-Minimal.iso

Install some added packages:

    echo << EOF > /etc/yum.repos.d/kvm-common.repo
    [kvm-common]
    name=KVM Common
    baseurl=http://mirror.centos.org/centos/7/virt/x86_64/kvm-common/
    gpgcheck=0
    enabled=1
    EOF

    yum -y install wget git net-tools bind bind-utils bash-completion nfs-utils rsync ipmitool python3-pip yum-utils qemu-kvm libvirt libvirt-python libguestfs-tools virt-install iscsi-initiator-utils createrepo docker libassuan-devel java-1.8.0-openjdk.x86_64

    systemctl enable --now docker
    systemctl enable --now libvirtd

Now, step through each of the tasks below:

1. [DNS Setup](DNS_Config.md)
2. [Nginx Setup & RPM Repo sync](Nginx_Config.md)
3. [Sonatype Nexus Setup](Nexus_Config.md)
4. Optional: [Setting Up PXE](CP_PXE_Setup.md)  Do this if you did not set up your router for [PXE](GL-AR750S-Ext.md).

When you are done configuring your control plane server, continue on to [setting up guest VMs](Provisioning_Hosts.md).
