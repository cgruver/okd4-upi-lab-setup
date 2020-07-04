## Setting up the Bastion host

The bastion host is generically what I call the system that hosts utilities in support of the rest of the lab.  It is also configured for password-less SSH into the rest of the lab.

The bastion host serves:

* Nginx for hosting RPMs and install files for KVM hosts and guests.
* A DNS server for the lab ecosystem.
* Sonatype Nexus for the OKD registry mirror, Maven Artifacts, and Container Images.

I recommend using a bare-metal host for your Bastion.  It will also run the load-balancer VM and Bootstrap VM for your cluster.  I am using a [NUC8i3BEK](https://ark.intel.com/content/www/us/en/ark/products/126149/intel-nuc-kit-nuc8i3bek.html) with 32GB of RAM for my Bastion host. This little box with 32GB of RAM is perfect for this purpose, and also very portable for throwing in a bag to take my dev environment with me.  My OpenShift build environment is also installed on the Bastion host.

You need to start with a minimal CentOS 7 install. (__This tutorial assumes that you are comfortable installing a Linux OS.__)

    wget https://buildlogs.centos.org/rolling/7/isos/x86_64/CentOS-7-x86_64-Minimal.iso

I use [balenaEtcher](https://www.balena.io/etcher/) to create a bootable USB key from a CentOS ISO.

You will have to attach monitor, mouse, and keyboard to your NUC for the install.  After the install, these machines will be headless.  So, no need for a complicated KVM setup...  The other, older meaning of KVM...  not confusing at all.

### Install CentOS: (Choose a Minimal Install)

* Network:
    * Configure the network interface with a fixed IP address, `10.11.11.10` if you are following this guide exactly.
    * Set the system hostname to `bastion`
* Storage:
    * Allocate 100GB for the `/` filesystem
    * Do not create a `/home` filesystem (no users on this system)
    * Allocate the remaining disk space for the VM guest filesystem
        * I put my KVM guests in `/VirtualMachines` 

After the installation completes, ensure that you can ssh to your host.

    ssh root@10.11.11.10

Create an SSH key pair on your workstation, if you don't already have one:

    ssh-keygen  # Take all the defaults

Enable password-less SSH:

    ssh-copy-id root@10.11.11.10

Shutdown the host and disconnect the keyboard, mouse, and display.  Your host is now headless.  

### __Power the host back on, log in via SSH, and continue the Bastion host set up.__

Install some added packages:

1. We're going to use the kvm-common repository to ensure we get a new enough version of KVM.

       cat << EOF > /etc/yum.repos.d/kvm-common.repo
       [kvm-common]
       name=KVM Common
       baseurl=http://mirror.centos.org/centos/7/virt/x86_64/kvm-common/
       gpgcheck=0
       enabled=1
       EOF

1. Now install the packages that we are going to need.

       yum -y install wget gcc git net-tools bind bind-utils bash-completion nfs-utils rsync ipmitool python3-pip yum-utils qemu-kvm libvirt libvirt-python libguestfs-tools virt-install iscsi-initiator-utils createrepo docker libassuan-devel java-1.8.0-openjdk.x86_64 epel-release ipxe-bootimgs python36-devel libvirt-devel httpd-tools

1. Install Virtual BMC:

       pip3.6 install virtualbmc

    Set up VBMC as a systemd controlled service:

       cat > /etc/systemd/system/vbmcd.service <<EOF
       [Install]
       WantedBy = multi-user.target
       [Service]
       BlockIOAccounting = True
       CPUAccounting = True
       ExecReload = /bin/kill -1 $MAINPID
       ExecStop = /bin/kill -15 $MAINPID
       ExecStart = /usr/local/bin/vbmcd --foreground
       Group = root
       Restart = on-failure
       RestartSec = 2
       Slice = vbmc.slice
       TimeoutSec = 120
       Type = simple
       User = root
       [Unit]
       After = libvirtd.service
       After = syslog.target
       After = network.target
       Description = vbmc service
       EOF

    Enable the vbmcd service:

       systemctl enable vbmcd.service
       systemctl start vbmcd.service

Clone this project:

    git clone https://github.com/cgruver/okd4-upi-lab-setup
    cd okd4-upi-lab-setup

Copy the utility scripts that I have prepared for you:

    mkdir -p ~/bin/lab_bin
    cp ./Provisioning/bin/*.sh ~/bin/lab_bin
    chmod 700 ~/bin/lab_bin/*.sh

Next, we need to set up some environment variables that we will use to set up the rest of the lab.  You need to make some decisions at this point, fill in the following information, and then edit `~/bin/lab_bin/setLabEnv.sh` accordingly:

| Variable | Example Value | Description |
| --- | --- | --- |
| `LAB_DOMAIN` | `your.domain.org` | The domain that you want for your lab.  This will be part of your DNS setup | 
| `BASTION_HOST` | `10.11.11.10` | The IP address of your bastion host. |
| `INSTALL_HOST` | `10.11.11.10` | The IP address of your Nginx Server, likely your bastion host. |
| `PXE_HOST` | `10.11.11.10` | The IP address of your iPXE server, either your OpenWRT router, or your bastion host. |
| `LAB_NAMESERVER` | `10.11.11.10` | The IP address of your Name Server, likely your bastion host. |
| `LAB_GATEWAY` | `10.11.11.1` | The IP address of your router |
| `LAB_NETMASK` | `255.255.255.0` | The netmask of your router |
| `INSTALL_ROOT` | `/usr/share/nginx/html/install` | The directory that will hold CentOS install images |
| `REPO_PATH` | `/usr/share/nginx/html/repos` | The directory on your Nginx server that will hold an RPM repository mirror |
| `OKD4_LAB_PATH` | `~/okd4-lab` | The path from which we will build our OKD4 cluster |
| `OKD_REGISTRY` | `registry.svc.ci.openshift.org/origin/release` | This is where we will get our OKD 4 images from to populate our local mirror |
| `LOCAL_REGISTRY` | `nexus.${LAB_DOMAIN}:5001` | The URL that we will use for our local mirror of the OKD registry images | 
| `LOCAL_REPOSITORY` | `origin` | The repository where the local OKD image mirror will be pushed |
| `LOCAL_SECRET_JSON` | `${OKD4_LAB_PATH}/pull_secret.json` | The path to the pull secret that we will need for mirroring OKD images |

After you have edited `~/bin/lab_bin/setLabEnv.sh` to reflect the values above, configure bash to execute this script on login:

    chmod 750 ~/bin/lab_bin/setLabEnv.sh
    echo ". /root/bin/lab_bin/setLabEnv.sh" >> ~/.bashrc



Enable this host to be a time server for the rest of your lab: (adjust the network value if you are using a different IP range)

    echo "allow 10.11.11.0/24" >> /etc/chrony.conf

Create a network bridge that will be used by our HA Proxy server and the OKD bootstrap node:

1. You need to identify the NIC that you configured when you installed this host.  It will be something like `eno1`, or `enp108s0u1`

       ip addr

    You will see out put like:

       1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
       link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
       inet 127.0.0.1/8 scope host lo
          valid_lft forever preferred_lft forever
       inet6 ::1/128 scope host 
          valid_lft forever preferred_lft forever

       ....

       15: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
       link/ether 1c:69:7a:03:21:e9 brd ff:ff:ff:ff:ff:ff
       inet 10.11.11.10/24 brd 10.11.11.255 scope global noprefixroute br0
          valid_lft forever preferred_lft forever
       inet6 fe80::1e69:7aff:fe03:21e9/64 scope link 
          valid_lft forever preferred_lft forever

    Somewhere in the output will be the interface that you configured with your bastion IP address.  Find it and set a variable with that value:

       PRIMARY_NIC="eno1"

1. Create a network bridge device named `br0`

       nmcli connection add type bridge ifname br0 con-name br0 ipv4.method manual ipv4.address "${BASTION_HOST}/24" ipv4.gateway "${LAB_GATEWAY}" ipv4.dns "${LAB_NAMESERVER}" ipv4.dns-search "${LAB_DOMAIN}" ipv4.never-default no connection.autoconnect yes bridge.stp no ipv6.method ignore 

1. Create a slave device for your primary NIC

       nmcli con add type ethernet con-name br0-slave-1 ifname ${PRIMARY_NIC} master br0

1. Delete the configuration of the primary NIC

       nmcli con del ${PRIMARY_NIC}

1. Put it back disabled

       nmcli con add type ethernet con-name ${PRIMARY_NIC} ifname ${PRIMARY_NIC} connection.autoconnect no ipv4.method disabled ipv6.method ignore

Finally, create an SSH key pair: (Take the defaults for all of the prompts, don't set a key password)

    ssh-keygen
    <Enter>
    <Enter>
    <Enter>

Now is a good time to update and reboot the bastion host:

    yum -y update
    shutdown -r now

Log back in and you should see all of the environment variables that we just set in the output of an `env` command.

__For the rest of this setup, unless otherwise specified, it is assumed that you are working from the Bastion Host.  You will need the environment variables that we just set up for some of the commands that you will be executing.__

Now we are ready to set up DNS: Go to [DNS Setup](DNS_Config.md)
