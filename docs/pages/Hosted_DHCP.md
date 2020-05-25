## Adding PXE capability to your Bastion host server

At this point you need to have set up DNS and HTTP on your Bastion host server.  [Setting Up Bastion host](Control_Plane.md)

First let's install and enable a TFTP server:

    yum -y install tftp tftp-server xinetd
    systemctl start xinetd
    systemctl enable xinetd
    firewall-cmd --add-port=69/tcp --permanent
    firewall-cmd --add-port=69/udp --permanent
    firewall-cmd --reload

Edit the tftp configuration file to enable tftp.  Set `disable = no`

    vi /etc/xinetd.d/tftp

    # default: off
    # description: The tftp server serves files using the trivial file transfer \
    #	protocol.  The tftp protocol is often used to boot diskless \
    #	workstations, download configuration files to network-aware printers, \
    #	and to start the installation process for some operating systems.
    service tftp
    {
    	socket_type		= dgram
    	protocol		= udp
    	wait			= yes
    	user			= root
    	server			= /usr/sbin/in.tftpd
    	server_args		= -s /var/lib/tftpboot
    	disable			= no
    	per_source		= 11
    	cps			= 100 2
    	flags			= IPv4
    }

With TFTP enabled, we need to copy over some files for it to serve up.  Assuming that you have already [set up NGINX](Nginx_Config.md), do the following:

    mkdir -p /var/lib/tftpboot/networkboot
    cd /usr/share/nginx/html/install/centos/
    cp ./EFI/BOOT/BOOTX64.EFI /var/lib/tftpboot
    cp ./images/pxeboot/initrd.img /var/lib/tftpboot/networkboot
    cp ./images/pxeboot/vmlinuz /var/lib/tftpboot/networkboot

We have one more step with TFTP, and that is the grub.cfg file.  I have provided one for you in the `PXE_Setup` folder within this project.  It needs to be configured with the IP address of your HTTP server that is hosting your Install repository, kickstart, firstboot, and hostconfig files.  See [Host OS Provisioning](Setup_Env.md)

    cd PXE_Setup
    mkdir tmp_work
    cp grub.cfg tmp_work
    cd tmp_work
    sed -i "s|%%HTTP_IP%%|10.11.11.10|g" ./grub.cfg  # Replace with the IP address of your Bastion host Server.
    scp grub.cfg root@10.11.11.10:/mnt/sda1/tftpboot # Replace with the IP address of your Bastion host Server.
    cd ..
    rm -rf tmp_work

Finally, your DHCP server needs to be able to direct PXE Boot clients to your TFTP server.  This is normally done by configuring a couple of parameters in your DHCP server, which will look something like:

    next-server = 10.11.11.10  # The IP address of your TFTP server
    filename = "BOOTX64.EFI"

Unfortunately, most home routers don't support the configuration of those parameters.  Your options here are either to use my recommended GL-AR750S-Ext travel router, or configure your Bastion host to serve DHCP.

__Warning:__ If you set up DHCP on the Bastion host you will either have to disable DHCP in your home router, or put your lab on another subnet.  I can't recommend the GL-AR750S-Ext enough.

### DHCP on Linux:

If you are going to set up your own DHCP server on the Bastion host, do the following:

    yum -y install dhcp
    firewall-cmd --add-service=dhcp --permanent
    firewall-cmd --reload

Now edit the DHCP configuration:

    vi /etc/dhcp/dhcpd.conf

    # DHCP Server Configuration file.

    ddns-update-style interim;
    ignore client-updates;
    authoritative;
    allow booting;
    allow bootp;
    allow unknown-clients;

    # internal subnet for my DHCP Server
    subnet 10.10.11.0 netmask 255.255.255.0 {
    range 10.10.11.11 10.10.11.29;
    option domain-name-servers 10.10.11.10;
    option domain-name "your.domain.org";
    option routers 10.10.11.1;
    option broadcast-address 10.10.11.255;
    default-lease-time 600;
    max-lease-time 7200;

    # IP of TFTP Server
    next-server 10.10.11.10;
    filename "BOOTX64.EFI";
    }

Finally, enable DHCP:

    systemctl enable dhcpd
    systemctl start dhcpd
