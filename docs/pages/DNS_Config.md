## DNS Configuration

This tutorial includes pre-configured files for you to modify for your specific installation.  These files will go into your `/etc` directory.  You will need to modify them for your specific setup.

    /etc/named.conf
    /etc/named/named.conf.local
    /etc/named/zones/db.10.11.11
    /etc/named/zones/db.your.domain.org
    /etc/named/zones/db.sinkhole

__If you set up your lab router on the 10.11.11/24 network.  Then you can use the example DNS files as they are for this exercise.__

Do the following, from the root of this project:

    cp ./DNS/named.conf /etc
    cp ./DNS/named /etc
    export LAB_DOMAIN=your.domain.org # Put your domain name here
    mv /etc/named/zones/db.your.domain.org /etc/named/zones/db.${LAB_DOMAIN} # Don't substitute your.domain.org in this line
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/named.conf.local
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/zones/db.${LAB_DOMAIN}
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/zones/db.10.11.11
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/zones/db.sinkhole

Now let's talk about this configuration, starting with the A records, (forward lookup zone).  If you did not use the 10.11.11/24 network as illustrated, then rename the file, `/etc/named/zones/db.your.domain.org`, to reflect your local domain.  Then edit it to reflect the appropriate A records for your setup.

In the example file, there are some entries to take note of:

1. The KVM hosts are named `kvm-host01`, `kvm-host02`, etc...  Modify this to reflect the number of KVM hosts that your lab setup with have.  The example allows for three hosts.
  
1. The control plane server is `bastion`.  If your control plane is also one of your KVM hosts, then you do not need a separate A record for this.
  
1. The Sonatype Nexus server gets it's own alias A record, `nexus.your.domain.org`.  This is not strictly necessary, but I find it useful.  For your lab, make sure that this A record reflects the IP address of the server where you have installed Nexus.  In this example, it is installed on the bastion host.
  
1. These example files contain references for a full OpenShift cluster with an haproxy load balancer.  The OKD cluster has three each of master, infrastructure, and application (compute) nodes.  In this tutorial, you will build a minimal cluster with one master node, one infrastructure node, and two application nodes.

    There are also records for four "SAN" nodes which I use to host a GlusterFS implementation, as well as records for three "DB" hosts which I use to host a MariaDB Galera cluster.  More on these later.

     __Remove superflouous entries from these files as needed.__
  
1. There are two wildcard records that OpenShift needs.
  
        *.prd-infra.your.domain.com
        *.prd-apps.your.domain.com
   
     The "infra" record is for your OpenShift console and other Infrastructure interfaces and APIs.  The "apps" record will be for all of the applications that you deploy into your OpenShift cluster.  The names of the wildcard records are arbitrary.  I have chosen prd-infra, and prd-apps to reflect the infrastruture and application interfaces for my "production" OpenShift cluster.

     These wildcard A records need to point to the entry point for your OpenShift cluster.  If you build a cluster with three master nodes and three infrastruture nodes, you will need a load balancer in front of the cluster.  In this case, your wildcard A records will point to the IP address of your load balancer.  Never fear, I will show you how to deploy a load balancer.  
     
     If you are building a simpler cluster, with only one master node and one infrastructure node, then the wildcard records can simply point to the IP address of your nodes.  In this case `prd-infra` will point to your master node IP and `prd-apps` will point to your infrastructure node.  I realize this is slightly confusing.  Master is "infra" and Infra is "apps".  This is really a reflection of the architecture of OpenShift itself.  The "Master" nodes are hosting the infrastructure that manages the OpenShift cluster itself.  The "Infrastructure" nodes are hosting the infrastructure that supports your applications.  This is an oversimplification, but it will suffice for now.

When you have completed all of your configuration changes, you can test the configuration with the following command:

        named-checkconf

    If the output is clean, then you are ready to fire it up!

### Starting DNS

Now that we are done with the configuration let's enable DNS and start it up.

    firewall-cmd --permanent --add-service=dns
    firewall-cmd --reload
    systemctl enable named
    systemctl start named

You can now test DNS resolution.  Try some `pings` or `dig` commands.

### __Hugely Helpful Tip:__

__If you are using a MacBook for your workstation, you can enable DNS resolution to your lab by creating a file in the `/etc/resolver` directory on your Mac.__

    sudo bash
    <enter your password>
    vi /etc/resolver/your.domain.com

Name the file `your.domain.com` after the domain that you created for your lab.  Enter something like this example, modified for your DNS server's IP:

    nameserver 10.11.11.10

Save the file.

Your MacBook should now query your new DNS server for entries in your new domain.  __Note:__ If your MacBook is on a different network and is routed to your Lab network, then the `acl` entry in your DNS configuration must allow your external network to query.  Otherwise, you will bang your head wondering why it does not work...  __The ACL is very powerful.  Use it.  Just like you are using firewalld.  Right?  I know you did not disable it when you installed your host...__

### On to the next...

Now that we have DNS configured, continue on to [Nginx Setup](Nginx_Config.md).
