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
    cp -r ./DNS/named /etc
    
    mv /etc/named/zones/db.your.domain.org /etc/named/zones/db.${LAB_DOMAIN} # Don't substitute your.domain.org in this line
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/named.conf.local
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/zones/db.${LAB_DOMAIN}
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/zones/db.10.11.11
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/named/zones/db.sinkhole

Now let's talk about this configuration, starting with the A records, (forward lookup zone).  If you did not use the 10.11.11/24 network as illustrated, then you will have to edit the files to reflect the appropriate A and PTR records for your setup.

In the example file, there are some entries to take note of:

1. The KVM hosts are named `kvm-host01`, `kvm-host02`, etc...  Modify this to reflect the number of KVM hosts that your lab setup with have.  The example allows for three hosts.
  
1. The Bastion Host is `bastion`.
  
1. The Sonatype Nexus server gets it's own alias A record, `nexus.your.domain.org`.  This is not strictly necessary, but I find it useful.  For your lab, make sure that this A record reflects the IP address of the server where you have installed Nexus.  In this example, it is installed on the bastion host.
  
1. These example files contain references for a full OpenShift cluster with an haproxy load balancer.  The OKD cluster has three each of master, and worker (compute) nodes.  In this tutorial, you will build a minimal cluster with three master nodes which are also schedulable as workers.

     __Remove or add entries to these files as needed for your setup.__
  
1. There is one wildcard record that OKD needs: __`okd4` is the name of the cluster.__
  
        *.apps.okd4.your.domain.org
   
     The "apps" record will be for all of the applications that you deploy into your OKD cluster.

     This wildcard A record needs to point to the entry point for your OKD cluster.  If you build a cluster with three master nodes like we are doing here, you will need a load balancer in front of the cluster.  In this case, your wildcard A records will point to the IP address of your load balancer.  Never fear, I will show you how to deploy an HA-Proxy load balancer.  

1. There are two A records for the Kubernetes API, internal & external.  In this case, the same load balancer is handling both.  So, they both point to the IP address of the load balancer.  __Again, `okd4` is the name of the cluster.__

       api.okd4.your.domain.org.        IN      A      10.10.11.50
       api-int.okd4.your.domain.org.    IN      A      10.10.11.50

1. There are three SRV records for the etcd hosts.

       _etcd-server-ssl._tcp.okd4.your.domain.org    86400     IN    SRV     0    10    2380    etcd-0.okd4.your.domain.org.
       _etcd-server-ssl._tcp.okd4.your.domain.org    86400     IN    SRV     0    10    2380    etcd-1.okd4.your.domain.org.
       _etcd-server-ssl._tcp.okd4.your.domain.org    86400     IN    SRV     0    10    2380    etcd-2.okd4.your.domain.org.

1. The db.sinkhole file is used to block DNS requests to `registry.svc.ci.openshift.org`.  This forces the OKD installation to use the Nexus mirror that we will create.  This file is modified by the utility scripts that I provided to enable and disable access to `registry.svc.ci.openshift.org` accordingly.

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
