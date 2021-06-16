# Lab Router

## Setting up DHCP, DNS, and iPXE booting

Your DHCP server needs to be able to direct PXE Boot clients to a TFTP server.  This is normally done by configuring a couple of parameters in your DHCP server, which will look something like:

```bash
next-server = 10.11.11.10  # The IP address of your TFTP server
filename = "ipxe.efi"
```

Unfortunately, most home routers don't support the configuration of those parameters.  At this point you have an option.  You can either set up TFTP and DHCP on your bastion host, or you can use an OpenWRT based router.  I have included instructions for setting up the GL.iNET GL-MV1000, GL-MV1000W, or GL-AR750S-Ext Travel Router.  

If you are configuring PXE on the bastion host, the continue on to: [Set up Bastion Host](Bastion.md)

If you are using the GL-AR750S-Ext, you will need a Micro SD card that is formatted with an EXT file-system.  The GL-MV1000, or GL-MV1000W has on-board storage that is sufficient for this configuration.

__GL-AR750S-Ext:__ From a linux host, insert the micro SD card, and run the following:

```bash
mkfs.ext4 /dev/sdc1 <replace with the device representing your sdcard>
```

Insert the SD card into the router.  It will mount at `/mnt/sda1`, or `/mnt/sda` if you did not create a partition, but formatted the whole card.

You will need to enable root ssh access to your router.  The best way to do this is by adding an SSH key.  __Don't allow password access over ssh.__  We already created an SSH key for our Bastion host, so we'll use that.  If you want to enable SSH access from your workstation as well, then follow the same instructions to create/add that key as well.  We will also set the router IP address to `10.11.11.1`

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

If you are using the `GL-AR750S-Ext`, note that I create a symbolic link from the SD card to /data so that the configuration matches the configuration of the `GL-MV1000`.  Since I have both, this keeps things consistent.

```bash
ln -s /mnt/sda1 /data        # This is not necessary for the GL-MV1000
```

Now we will enable TFTP and iPXE:

```bash
mkdir -p /data/tftpboot/ipxe
mkdir /data/tftpboot/networkboot

uci add_list dhcp.lan.dhcp_option="6,10.11.11.10,8.8.8.8,8.8.4.4"
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
uci set dhcp.uefi.serveraddress='10.11.11.1'
uci set dhcp.uefi.servername='pxe'
uci set dhcp.uefi.force='1'
uci set dhcp.ipxe=boot
uci set dhcp.ipxe.filename='tag:ipxe,boot.ipxe'
uci set dhcp.ipxe.serveraddress='10.11.11.1'
uci set dhcp.ipxe.servername='pxe'
uci set dhcp.ipxe.force='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

That's a lot of `uci` commands that we just did.  I won't drain the list, but I will explain at a high level, because some of this is not well documented by OpenWRT, and is the result of a LOT of Googling on my part.

* `uci add_list dhcp.lan.dhcp_option="6,10.11.11.10,8.8.8.8,8.8.4.4"`  This is setting DHCP option 6, (DNS Servers), it represents the list of DNS servers that the DHCP client should use for name resolution.
* `uci set dhcp.efi64_boot_1=match`  This series of commands creates a DHCP match for DHCP option 60 in the request.  If the vendor class identifier is `7` or `9`, then the match variable, (`networkid`), is set to `efi64` which is arbitrary, but matchable in the `boot` sections which come after.
* `uci set dhcp.ipxe_boot=userclass`  This series of commands looks for a userclass of `iPXE` in the DHCP request and sets the `networkid` variable to `ipxe`.
* `uci set dhcp.uefi=boot` This series of commands looks for a `networkid` match against either `efi64` or `ipxe` and sends the appropriate PXE response back to the client.

With the router configured, it's now time to set up the files for iPXE.

First, let's install some additional packages on our router:

```bash
opkg update
opkg install wget git-http ca-bundle haproxy bind-server bind-tools bash
```

Download the UEFI iPXE boot image:

```bash
wget http://boot.ipxe.org/ipxe.efi -O /data/tftpboot/ipxe.efi
```

Create this initial boot file:

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
git clone https://github.com/cgruver/okd4-upi-lab-setup
cd okd4-upi-lab-setup
mkdir -p /etc/profile.d

echo ". /root/bin/lab_bin/setLabEnv.sh" >> /etc/profile.d/lab.sh
```

Log out, then back in.  Check that the env settings are as expected.

```bash
LAB_NET=$(ip -br addr show dev br-lan label br-lan | cut -d" " -f1)
export LAB_DOMAIN=your.lab.domain

```




This tutorial includes pre-configured files for you to modify for your specific installation.  These files will go into your `/etc/bind` directory.  You will need to modify them for your specific setup.

```bash
/etc/bind/named.conf
/etc/bind/named.conf.local
/etc/bind/zones/db.10.11.11
/etc/bind/zones/db.your.domain.org
/etc/bind/zones/db.sinkhole
```

__If you set up your lab router on the 10.11.11/24 network.  Then you can use the example DNS files as they are for this exercise.__

Do the following, from the root of this project:

```bash
mv /etc/bind/named.conf /etc/bind/named.conf.orig
cp ./DNS/named.conf /etc/bind
cp -r ./DNS/named/* /etc/bind

mv /etc/bind/zones/db.your.domain.org /etc/bind/zones/db.${LAB_DOMAIN} # Don't substitute your.domain.org in this line
sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/bind/named.conf.local
sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/bind/zones/db.${LAB_DOMAIN}
sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/bind/zones/db.10.11.11
sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/bind/zones/db.sinkhole
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
firewall-cmd --permanent --add-service=dns
firewall-cmd --reload
systemctl enable named --now
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
nameserver 10.11.11.10
```

Save the file.

Your MacBook should now query your new DNS server for entries in your new domain.  __Note:__ If your MacBook is on a different network and is routed to your Lab network, then the `acl` entry in your DNS configuration must allow your external network to query.  Otherwise, you will bang your head wondering why it does not work...  __The ACL is very powerful.  Use it.  Just like you are using firewalld.  Right?  I know you did not disable it when you installed your host...__

__Your router is now ready to PXE boot hosts.__

## Set up Bastion Host

Now, let's try out our new configuration by using PXE to set up our bastion host.

We are going to create a kickstart file for the bastion host.

Continue on to set up your Nexus: [Sonatype Nexus Setup](Nexus_Config.md)
