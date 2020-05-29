## Manual KVM Host install

Assuming you already have a USB key with the Centos 7 install ISO on it, do the following:

Ensure that you have DNS `A` and `PTR` records for each host.  The DNS files that you set up in [DNS Setup](DNS_Config.md) contain records for 3 kvm-hosts.

### Install CentOS: (Choose a Minimal Install)

* Network:
  * Configure the network interface with a fixed IP address
  * If you are following this guide exactly:
    * Set the following Hostnames an IP
    * `kvm-host01` `10.11.11.200`
    * `kvm-host02` `10.11.11.201`
    * Continue this pattern if you have multiple KVM hosts.
* Storage:
    * Allocate 100GB for the `/` filesystem
    * Do not create a `/home` filesystem (no users on this system)
    * Allocate the remaining disk space for the VM guest filesystem
        * I put my KVM guests in `/VirtualMachines` 

After the installation completes,  ensure that you can ssh to your host from your bastion.

    ssh-copy-id root@kvm-host01.${LAB_DOMAIN}
    ssh root@kvm-host01.${LAB_DOMAIN} "uname -a"

    ssh-copy-id root@kvm-host01.${LAB_DOMAIN}
    ssh root@kvm-host01.${LAB_DOMAIN} "uname -a"

Then, disconnect the monitor, mouse and keyboard.

Set up KVM for each host.  Do the following for kvm-host01, and modify the IP info for each successive kvm-host that you build:

1. SSH to the host:

       ssh root@kvm-host01

1. Set up KVM:

       cat << EOF > /etc/yum.repos.d/kvm-common.repo
       [kvm-common]
       name=KVM Common
       baseurl=http://mirror.centos.org/centos/7/virt/x86_64/kvm-common/
       gpgcheck=0
       enabled=1
       EOF

       yum -y install wget git net-tools bind-utils bash-completion nfs-utils rsync qemu-kvm libvirt libvirt-python libguestfs-tools virt-install iscsi-initiator-utils
       yum -y update

       cat <<EOF >> /etc/modprobe.d/kvm.conf
       options kvm_intel nested=1
       EOF
       systemctl enable libvirtd

       mkdir /VirtualMachines
       virsh pool-destroy default
       virsh pool-undefine default

    If there is no default pool, the two commands above will fail.  This is OK, carry on.

       virsh pool-define-as --name default --type dir --target /VirtualMachines
       virsh pool-autostart default
       virsh pool-start default

1. Set up Network Bridge:

    You need to identify the NIC that you configured when you installed this host.  It will be something like `eno1`, or `enp108s0u1`

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
       IP=10.11.11.200   # Change this for kvm-host01, etc...

    Set the following variables from your bastion host: `LAB_DOMAIN`, `LAB_NAMESERVER`, `LAB_GATEWAY`

    1. Set the hostname:

       hostnamectl set-hostname kvm-host01.${LAB_DOMAIN}

    1. Create a network bridge device named `br0`

           nmcli connection add type bridge ifname br0 con-name br0 ipv4.method manual ipv4.address "${IP}/24" ipv4.gateway "${LAB_GATEWAY}" ipv4.dns "${LAB_NAMESERVER}" ipv4.dns-search "${LAB_DOMAIN}" ipv4.never-default no connection.autoconnect yes bridge.stp no ipv6.method ignore 

    1. Create a slave device for your primary NIC

           nmcli con add type ethernet con-name br0-slave-1 ifname ${PRIMARY_NIC} master br0

    1. Delete the configuration of the primary NIC

           nmcli con del ${PRIMARY_NIC}

    1. Put it back disabled

           nmcli con add type ethernet con-name ${PRIMARY_NIC} ifname ${PRIMARY_NIC} connection.autoconnect no ipv4.method disabled ipv6.method ignore

1. Reboot:

       shutdown -r now

Go ahead a build out all of your KVM hosts are this point.  For this lab you need at least one KVM host with 64GB of RAM.  With this configuration, you will build an OKD cluster with 3 Master nodes which are also schedulable, (is that a word?), as worker nodes.  If you have two, then you will build an OKD cluster with 3 Master and 3 Worker nodes.

It is now time to deploy an OKD cluster: [Deploy OKD](DeployOKD.md)
