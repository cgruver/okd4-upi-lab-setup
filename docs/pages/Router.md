---
layout: page
---
# Lab Router - GL.iNet GL-MV1000 or GL-MV1000W

[GL-MV1000](https://www.gl-inet.com/products/gl-mv1000/)  
[OpenWRT](https://openwrt.org)

## Setting up DHCP, DNS, and iPXE host install

You will need to enable root ssh access to your router.  The best way to do this is by adding an SSH key.  __Don't allow password access over ssh.__

1. Login to your router with a browser: `https://<Initial Router IP>`
1. Expand the `MORE SETTINGS` menu on the left, and select `LAN IP`
1. Fill in the following:

    |||
    |---|---|
    |LAN IP|10.11.11.1|
    |Start IP Address|10.11.11.11|
    |End IP Address|10.11.11.29|

1. Click `Apply`
1. Now, select the `Advanced` option from the left menu bar.
1. Login to the Advanced Administration console
1. Expand the `System` menu at the top of the screen, and select `Administration`
1. Select the `SSH Access` tab.
   1. Ensure that the Dropbear Instance `Interface` is set to `unspecified` and that the `Port` is `22`
   1. Ensure that the following are __NOT__ checked:
      * `Password authentication`
      * `Allow root logins with password`
      * `Gateway ports`
   1. Click `Save`
1. Select the `SSH-Keys` tab
    1. Paste your __*public*__ SSH key into the `SSH-Keys` section at the bottom of the page and select `Add Key`

        Your public SSH key is likely in the file `$HOME/.ssh/id_rsa.pub`
    1. Repeat with additional keys.
    1. Click `Save & Apply`

Now that we have enabled SSH access to the router, we will login and complete our setup from the command-line.

```bash
ssh root@<router IP>
```

If you are using the `GL-AR750S-Ext` you will need to add an sd-card, note that I create a symbolic link from the SD card to /data so that the configuration matches the configuration of the `GL-MV1000`.  Since I have both, this keeps things consistent.

```bash
ln -s /mnt/sda1 /data        # This is not necessary for the GL-MV1000 or GL-MV1000W
```

## Install some additional packages on your router

```bash
opkg update
opkg install wget git-http ca-bundle haproxy bind-server bind-tools bash
```

## Setup environment variables for your lab router

```bash
LAB_DOMAIN=your.lab.domain # Replace with the domain that you want to use for this router.
```

```bash
LAB_NET=$(ip -br addr show dev br-lan label br-lan | cut -d" " -f1)
LAB_ROUTER=$(echo ${LAB_NET} | cut -d"/" -f1)
LAB_CIDR=$(echo ${LAB_NET} | cut -d"/" -f2)
cidr2mask ()
{
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}
LAB_NETMASK=$(cidr2mask ${LAB_CIDR})


cat << EOF > /root/bin/setLabEnv.sh
export PATH=\$PATH:/root/bin
export LAB_DOMAIN=${LAB_DOMAIN}
export INSTALL_HOST=${LAB_ROUTER}
export PXE_HOST=${LAB_ROUTER}
export LAB_NAMESERVER=${LAB_ROUTER}
export LAB_ROUTER=${LAB_ROUTER}
export LAB_NETMASK=${LAB_NETMASK}
export HTML_ROOT=/www
export INSTALL_ROOT=${HTML_ROOT}/install
export REPO_PATH=${HTML_ROOT}/repos
export REPO_URL=http://${INSTALL_HOST}
export INSTALL_URL=http://${INSTALL_HOST}/install
EOF
chmod 750 /root/bin/setLabEnv.sh
mkdir -p /etc/profile.d
echo ". /root/bin/setLabEnv.sh" > /etc/profile.d/lab.sh
```

__Log out, then back in.  Check that the env settings are as expected.__

```bash
env
```

## Enable TFTP and iPXE

```bash
mkdir -p /data/tftpboot/ipxe
mkdir /data/tftpboot/networkboot

uci add_list dhcp.lan.dhcp_option="6,${LAB_ROUTER},8.8.8.8,8.8.4.4"
uci set dhcp.lan.leasetime="5m"
uci set dhcp.@dnsmasq[0].enable_tftp=1
uci set dhcp.@dnsmasq[0].tftp_root=/data/tftpboot
uci set dhcp.efi64_boot_1=match
uci set dhcp.efi64_boot_1.networkid='set:efi64'
uci set dhcp.efi64_boot_1.match='60,PXEClient:Arch:00007'
uci set dhcp.efi64_boot_2=match
uci set dhcp.efi64_boot_2.networkid='set:efi64'
uci set dhcp.efi64_boot_2.match='60,PXEClient:Arch:00009'
uci set dhcp.ipxe_boot=userclass
uci set dhcp.ipxe_boot.networkid='set:ipxe'
uci set dhcp.ipxe_boot.userclass='iPXE'
uci set dhcp.uefi=boot
uci set dhcp.uefi.filename='tag:efi64,tag:!ipxe,ipxe.efi'
uci set dhcp.uefi.serveraddress='${LAB_ROUTER}'
uci set dhcp.uefi.servername='pxe'
uci set dhcp.uefi.force='1'
uci set dhcp.ipxe=boot
uci set dhcp.ipxe.filename='tag:ipxe,boot.ipxe'
uci set dhcp.ipxe.serveraddress='${LAB_ROUTER}'
uci set dhcp.ipxe.servername='pxe'
uci set dhcp.ipxe.force='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

That's a lot of `uci` commands that we just did.  I won't drain the list, but I will explain at a high level, because some of this is not well documented by OpenWRT, and is the result of a LOT of Googling on my part.

* `uci add_list dhcp.lan.dhcp_option="6,${LAB_ROUTER},8.8.8.8,8.8.4.4"`  This is setting DHCP option 6, (DNS Servers), it represents the list of DNS servers that the DHCP client should use for name resolution.
* `uci set dhcp.efi64_boot_1=match`  This series of commands creates a DHCP match for DHCP option 60 in the request.  If the vendor class identifier is `7` or `9`, then the match variable, (`networkid`), is set to `efi64` which is arbitrary, but matchable in the `boot` sections which come after.
* `uci set dhcp.ipxe_boot=userclass`  This series of commands looks for a userclass of `iPXE` in the DHCP request and sets the `networkid` variable to `ipxe`.
* `uci set dhcp.uefi=boot` This series of commands looks for a `networkid` match against either `efi64` or `ipxe` and sends the appropriate PXE response back to the client.

With the router configured, it's now time to set up the files for iPXE.

Download the UEFI iPXE boot image:

```bash
wget http://boot.ipxe.org/ipxe.efi -O /data/tftpboot/ipxe.efi
```

Create the initial boot file:

```bash
cat << EOF > /data/tftpboot/boot.ipxe
#!ipxe

echo ========================================================
echo UUID: \${uuid}
echo Manufacturer: \${manufacturer}
echo Product name: \${product}
echo Hostname: \${hostname}
echo
echo MAC address: \${net0/mac}
echo IP address: \${net0/ip}
echo IPv6 address: \${net0.ndp.0/ip6:ipv6}
echo Netmask: \${net0/netmask}
echo
echo Gateway: \${gateway}
echo DNS: \${dns}
echo IPv6 DNS: \${dns6}
echo Domain: \${domain}
echo ========================================================

chain --replace --autofree ipxe/\${mac:hexhyp}.ipxe
EOF
```

Now copy the necessary files to the router:

```bash
mkdir -p /data/install/centos
wget -m -np -nH --cut-dirs=5 -P /data/install/centos http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/
```

```bash
cp /data/install/centos/isolinux/vmlinuz /data/tftpboot/networkboot
cp /data/install/centos/isolinux/initrd.img /data/tftpboot/networkboot
```

## DNS Configuration

```bash
mv /etc/bind/named.conf /etc/bind/named.conf.orig

LAB_CIDR=$(ip -br addr show dev br-lan label br-lan | cut -d" " -f1 | cut -d"/" -f2)

IFS=. read -r i1 i2 i3 i4 << EOF
${LAB_ROUTER}
EOF
net_addr=$(( ((1<<32)-1) & (((1<<32)-1) << (32 - ${LAB_CIDR})) ))
o1=$(( ${i1} & (${net_addr}>>24) ))
o2=$(( ${i2} & (${net_addr}>>16) ))
o3=$(( ${i3} & (${net_addr}>>8) ))
o4=$(( ${i4} & ${net_addr} ))

LAB_NETWORK=${o1}.${o2}.${o3}.${o4}
NET_PREFIX=${o1}.${o2}.${o3}
NET_PREFIX_ARPA=${o3}.${o2}.${o1}


cat << EOF > /etc/bind/named.conf
acl "trusted" {
 ${LAB_NETWORK}/${LAB_CIDR};
};

options {
 listen-on port 53 { 127.0.0.1; ${LAB_NAMESERVER}; };
 
 directory  "/data/var/named";
 dump-file  "/data/var/named/data/cache_dump.db";
 statistics-file "/data/var/named/data/named_stats.txt";
 memstatistics-file "/data/var/named/data/named_mem_stats.txt";
 allow-query     { trusted; };

 recursion yes;

 dnssec-enable yes;
 dnssec-validation yes;

 /* Path to ISC DLV key */
 bindkeys-file "/etc/bind/bind.keys";

 managed-keys-directory "/data/var/named/dynamic";

 pid-file "/var/run/named/named.pid";
 session-keyfile "/var/run/named/session.key";

 // Set up RPZ to block access to the OpenShift registry for mirrored installation
 response-policy { zone "sinkhole"; };
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
 type hint;
 file "/etc/bind/db.root";
};

zone "${LAB_DOMAIN}" {
    type master;
    file "/etc/bind/db.${LAB_DOMAIN}"; # zone file path
};

zone "${NET_PREFIX_ARPA}.in-addr.arpa" {
    type master;
    file "/etc/bind/db.${NET_PREFIX_ARPA}";
};

zone "sinkhole" {
    type master;
    file "/etc/bind/db.sinkhole"; allow-query {none;};
};

zone "localhost" {
    type master;
    file "/etc/bind/db.local";
};

zone "127.in-addr.arpa" {
    type master;
    file "/etc/bind/db.127";
};

zone "0.in-addr.arpa" {
    type master;
    file "/etc/bind/db.0";
};

zone "255.in-addr.arpa" {
    type master;
    file "/etc/bind/db.255";
};

EOF

cat << EOF > /etc/bind/db.${LAB_DOMAIN}
@       IN      SOA     router.${LAB_DOMAIN}. admin.${LAB_DOMAIN}. (
             3          ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; name servers - NS records
    IN      NS     router.${LAB_DOMAIN}.

; name servers - A records
router.${LAB_DOMAIN}.         IN      A      ${NET_PREFIX}.10

; ${LAB_NETWORK}/${LAB_CIDR} - A records
nexus.${LAB_DOMAIN}.           IN      A      ${LAB_ROUTER}
kvm-host01.${LAB_DOMAIN}.      IN      A      ${NET_PREFIX}.200
kvm-host02.${LAB_DOMAIN}.      IN      A      ${NET_PREFIX}.201
kvm-host03.${LAB_DOMAIN}.      IN      A      ${NET_PREFIX}.202
okd4-bootstrap.${LAB_DOMAIN}.  IN      A      ${NET_PREFIX}.49
okd4-lb01.${LAB_DOMAIN}.       IN      A      ${LAB_ROUTER}
*.apps.okd4.${LAB_DOMAIN}.     IN      A      ${LAB_ROUTER}
api.okd4.${LAB_DOMAIN}.        IN      A      ${LAB_ROUTER}
api-int.okd4.${LAB_DOMAIN}.    IN      A      ${LAB_ROUTER}
okd4-master-0.${LAB_DOMAIN}.   IN      A      ${NET_PREFIX}.60
etcd-0.${LAB_DOMAIN}.          IN      A      ${NET_PREFIX}.60
okd4-master-1.${LAB_DOMAIN}.   IN      A      ${NET_PREFIX}.61
etcd-1.${LAB_DOMAIN}.          IN      A      ${NET_PREFIX}.61
okd4-master-2.${LAB_DOMAIN}.   IN      A      ${NET_PREFIX}.62
etcd-2.${LAB_DOMAIN}.          IN      A      ${NET_PREFIX}.62
okd4-worker-0.${LAB_DOMAIN}.   IN      A      ${NET_PREFIX}.70
okd4-worker-1.${LAB_DOMAIN}.   IN      A      ${NET_PREFIX}.71
okd4-worker-2.${LAB_DOMAIN}.   IN      A      ${NET_PREFIX}.72

_etcd-server-ssl._tcp.okd4.${LAB_DOMAIN}    86400     IN    SRV     0    10    2380    etcd-0.okd4.${LAB_DOMAIN}.
_etcd-server-ssl._tcp.okd4.${LAB_DOMAIN}    86400     IN    SRV     0    10    2380    etcd-1.okd4.${LAB_DOMAIN}.
_etcd-server-ssl._tcp.okd4.${LAB_DOMAIN}    86400     IN    SRV     0    10    2380    etcd-2.okd4.${LAB_DOMAIN}.
EOF

cat << EOF > /etc/bind/db.${NET_PREFIX_ARPA}
@       IN      SOA     router.${LAB_DOMAIN}. admin.${LAB_DOMAIN}. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL

; name servers - NS records
      IN      NS      router.${LAB_DOMAIN}.

; PTR Records
1.${NET_PREFIX_ARPA}    IN      PTR     router.${LAB_DOMAIN}.
200.${NET_PREFIX_ARPA}   IN      PTR     kvm-host01.${LAB_DOMAIN}. 
201.${NET_PREFIX_ARPA}   IN      PTR     kvm-host02.${LAB_DOMAIN}. 
202.${NET_PREFIX_ARPA}   IN      PTR     kvm-host03.${LAB_DOMAIN}. 
49.${NET_PREFIX_ARPA}    IN      PTR     okd4-bootstrap.${LAB_DOMAIN}.  
60.${NET_PREFIX_ARPA}    IN      PTR     okd4-master-0.${LAB_DOMAIN}. 
61.${NET_PREFIX_ARPA}    IN      PTR     okd4-master-1.${LAB_DOMAIN}. 
62.${NET_PREFIX_ARPA}    IN      PTR     okd4-master-2.${LAB_DOMAIN}. 
70.${NET_PREFIX_ARPA}    IN      PTR     okd4-worker-0.${LAB_DOMAIN}. 
71.${NET_PREFIX_ARPA}    IN      PTR     okd4-worker-1.${LAB_DOMAIN}. 
72.${NET_PREFIX_ARPA}    IN      PTR     okd4-worker-2.${LAB_DOMAIN}. 
EOF

cat << EOF > /etc/bind/db.sinkhole
@       IN      SOA     router.${LAB_DOMAIN}. admin.${LAB_DOMAIN}. (
                              3         ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800 )   ; Negative Cache TTL
;
; name servers - NS records
    IN      NS     router.${LAB_DOMAIN}.

;sinkhole-openshift     CNAME    . ;
;sinkhole-quay    CNAME    . ;
;sinkhole-dockerhub    CNAME    . ;
;sinkhole-github    CNAME    . ;
EOF

mkdir -p /data/var/named/dynamic
mkdir /data/var/named/data
chown -R bind:bind /data/var/named
chown -R bind:bind /etc/bind
```

```bash
/usr/sbin/named -u bind -g -c /etc/bind/named.conf
```

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

    ```bash
    api.okd4.your.domain.org.        IN      A      10.10.11.50
    api-int.okd4.your.domain.org.    IN      A      10.10.11.50
    ```

1. There are three SRV records for the etcd hosts.

    ```bash
    _etcd-server-ssl._tcp.okd4.your.domain.org    86400     IN    SRV     0    10    2380    etcd-0.okd4.your.domain.org.
    _etcd-server-ssl._tcp.okd4.your.domain.org    86400     IN    SRV     0    10    2380    etcd-1.okd4.your.domain.org.
    _etcd-server-ssl._tcp.okd4.your.domain.org    86400     IN    SRV     0    10    2380    etcd-2.okd4.your.domain.org.
    ```

1. The db.sinkhole file is used to block DNS requests to `registry.svc.ci.openshift.org`.  This forces the OKD installation to use the Nexus mirror that we will create.  This file is modified by the utility scripts that I provided to enable and disable access to `registry.svc.ci.openshift.org` accordingly.

When you have completed all of your configuration changes, you can test the configuration with the following command:

    ```bash
    named-checkconf
    ```

    If the output is clean, then you are ready to fire it up!

### Starting DNS

Now that we are done with the configuration let's enable DNS and start it up.

```bash
uci set dhcp.@dnsmasq[0].domain='${LAB_DOMAIN}'
uci set dhcp.@dnsmasq[0].localuse=0
uci set dhcp.@dnsmasq[0].cachelocal=0
uci set dhcp.@dnsmasq[0].port=0
uci commit dhcp
/etc/init.d/dnsmasq restart
/etc/init.d/named enable
/etc/init.d/named start
```

You can now test DNS resolution.  Try some `pings` or `dig` commands.

### __Hugely Helpful Tip:__

__If you are using a MacBook for your workstation, you can enable DNS resolution to your lab by creating a file in the `/etc/resolver` directory on your Mac.__

```bash
sudo bash
<enter your password>
vi /etc/resolver/your.domain.com
```

Name the file `your.domain.com` after the domain that you created for your lab.  Enter something like this example, modified for your DNS server's IP:

```bash
nameserver 10.11.11.1
```

Save the file.

Your MacBook should now query your new DNS server for entries in your new domain.  __Note:__ If your MacBook is on a different network and is routed to your Lab network, then the `acl` entry in your DNS configuration must allow your external network to query.  Otherwise, you will bang your head wondering why it does not work...  __The ACL is very powerful.  Use it.  Just like you are using firewalld.  Right?  I know you did not disable it...  surely not...  if you did...  TURN IT BACK ON NOW!!!  NOW, NOW, NOW, NOW..., NOW!__

__Your router is now ready to PXE boot hosts.__

## Set up Bastion Host

Now, let's try out our new configuration by using PXE to set up our bastion host.

We are going to create a kickstart file for the bastion host.

Continue on to set up your Nexus: [Sonatype Nexus Setup](Nexus_Config.md)

## Set up HA Proxy

```bash
mv /etc/haproxy.cfg /etc/haproxy.cfg.orig

uci del_list uhttpd.main.listen_http="[::]:80"
uci del_list uhttpd.main.listen_http="0.0.0.0:80"
uci del_list uhttpd.main.listen_https="[::]:443"
uci del_list uhttpd.main.listen_https="0.0.0.0:443"
uci add_list uhttpd.main.listen_http="${LAB_ROUTER}:80"
uci add_list uhttpd.main.listen_https="${LAB_ROUTER}:443"
uci add_list uhttpd.main.listen_http="127.0.0.1:80"
uci add_list uhttpd.main.listen_https="127.0.0.1:443"
uci commit uhttpd
/etc/init.d/uhttpd restart

uci set network.lan_lb01=interface
uci set network.lan_lb01.ifname='@lan'
uci set network.lan_lb01.proto='static'
uci set network.lan_lb01.hostname='okd4-lb01'
uci set network.lan_lb01.ipaddr='10.11.12.2/255.255.255.0'
uci commit network
/etc/init.d/network reload


cat << EOF > /etc/haproxy.cfg
global

    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     50000
    user        haproxy
    group       haproxy
    daemon

    stats socket /var/lib/haproxy/stats

defaults
    mode                    http
    log                     global
    option                  dontlognull
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          10m
    timeout server          10m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 50000

listen okd4-api 
    bind 0.0.0.0:6443
    balance roundrobin
    option                  tcplog
    mode tcp
    option tcpka
    option tcp-check
${API_LIST}

listen okd4-mc 
    bind 0.0.0.0:22623
    balance roundrobin
    option                  tcplog
    mode tcp
    option tcpka
${MC_LIST}

listen okd4-apps 
    bind 0.0.0.0:80
    balance source
    option                  tcplog
    mode tcp
    option tcpka
${APPS_LIST}

listen okd4-apps-ssl 
    bind 0.0.0.0:443
    balance source
    option                  tcplog
    mode tcp
    option tcpka
    option tcp-check
${APPS_SSL_LIST}
EOF
```

### Create CentOS Stream Repo Mirror:

```bash
for i in AppStream PowerTools extras
do 
  mkdir -p /data/repos/${i}
  wget -m -np -nH --cut-dirs=5 -P /data/repos/${i} http://mirror.centos.org/centos/8-stream/${i}/x86_64/os/
done

```
