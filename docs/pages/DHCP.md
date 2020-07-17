## Adding PXE Boot capability to your Bastion host server

Your DHCP server needs to be able to direct PXE Boot clients to a TFTP server.  This is normally done by configuring a couple of parameters in your DHCP server, which will look something like:

    next-server = 10.11.11.10  # The IP address of your TFTP server
    filename = "BOOTX64.EFI"

Unfortunately, most home routers don't support the configuration of those parameters.  At this point you have an option.  You can either set up TFTP and DHCP on your bastion host, or you can use an OpenWRT based router.  I have included instructions for setting up the GL.iNET GL-AR750S-Ext or GL-MV1000 Travel Router.  Follow those instructions here: [Travel Router Setup](GL-AR750S-Ext.md)

If you are configuring PXE on the bastion host, the continue on:

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

With TFTP configured, it's now time to copy over the files for iPXE.

This project has some files already prepared for you.  They are located in ./Provisioning/iPXE.

|||
|-|-|
| boot.ipxe | This is the initial iPXE bootstrap file.  It has logic in it to look for a file with the booting host's MAC address.  Otherwise it pulls the default.ipxe file. |
| default.ipxe | This file will initiate a kickstart install of CentOS 7 for non-OKD hosts. __This is not working yet__ |
| grub.cfg | Until I get iPXE working with intel NUC, we'll be using UEFI |

From the root directory of this project, execute the following:

    mkdir tmp-work
    mkdir -p /var/lib/tftpboot/networkboot
    mkdir /var/lib/tftpboot/ipxe
    cp ./Provisioning/iPXE/* ./tmp-work
    for i in $(ls ./tmp-work)
    do
        sed -i "s|%%INSTALL_URL%%|${INSTALL_URL}|g" ./tmp-work/${i}
    done
    cp ./tmp-work/boot.ipxe /var/lib/tftpboot/boot.ipxe
    cp ./tmp-work/default.ipxe /var/lib/tftpboot/ipxe/default.ipxe
    cp ./tmp-work/grub.cfg /var/lib/tftpboot
    mkdir -p ${OKD4_LAB_PATH}/ipxe-templates
    cp ./tmp-work/lab-guest.ipxe ${OKD4_LAB_PATH}/ipxe-templates/lab-guest.ipxe
    rm -rf ./tmp-work

    cp ${INSTALL_ROOT}/centos/EFI/BOOT/grubx64.efi /var/lib/tftpboot
    cp ${INSTALL_ROOT}/centos/EFI/BOOT/BOOTX64.EFI /var/lib/tftpboot
    cp ${INSTALL_ROOT}/centos/isolinux/vmlinuz /var/lib/tftpboot/networkboot
    cp ${INSTALL_ROOT}/centos/isolinux/initrd.img /var/lib/tftpboot/networkboot

__Warning:__ If you set up DHCP on the Bastion host you will either have to disable DHCP in your home router, or put your lab on an isolated network.  

### DHCP on Linux:

If you are going to set up your own DHCP server on the Bastion host, do the following:

    yum -y install dhcp
    firewall-cmd --add-service=dhcp --permanent
    firewall-cmd --reload

I have provided a DHCP configuration file for you.  From the root of this project:

    cp ./Provisioning/dhcpd.conf /etc/dhcp/dhcpd.conf
    sed -i "s|%%LAB_DOMAIN%%|${LAB_DOMAIN}|g" /etc/dhcp/dhcpd.conf

This configuration assumes that you are using the `10.11.11.0/24` network.  It configures a DHCP range of `10.10.11.11` - `10.10.11.29`

If you are using a different configuration, then edit /etc/dhcp/dhcpd.conf appropriately.

Finally, enable DHCP:

    systemctl enable dhcpd
    systemctl start dhcpd

Now, continue on to set up your Nexus: [Sonatype Nexus Setup](Nexus_Config.md)
