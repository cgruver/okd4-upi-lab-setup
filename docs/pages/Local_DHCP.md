## Adding PXE Boot capability to your Bastion host server



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
    	server_args		= -s /data/tftpboot
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
    mkdir -p /data/tftpboot/networkboot
    mkdir /data/tftpboot/ipxe
    cp ./Provisioning/iPXE/* ./tmp-work
    for i in $(ls ./tmp-work)
    do
        sed -i "s|%%INSTALL_URL%%|${INSTALL_URL}|g" ./tmp-work/${i}
    done
    cp ./Provisioning/iPXE/boot.ipxe /data/tftpboot/boot.ipxe

    wget http://boot.ipxe.org/ipxe.efi
    cp ./ipxe.efi /data/tftpboot/ipxe.efi
    rm -f ./ipxe.efi

    cp ${INSTALL_ROOT}/centos/isolinux/vmlinuz /data/tftpboot/networkboot
    cp ${INSTALL_ROOT}/centos/isolinux/initrd.img /data/tftpboot/networkboot

__Warning:__ If you set up DHCP on the Bastion host you will either have to disable DHCP in your home router, or put your lab on an isolated network.  

### DHCP on Linux:

If you are going to set up your own DHCP server on the Bastion host, do the following:

    dnf -y install dhcp
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
