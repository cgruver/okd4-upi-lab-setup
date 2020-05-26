## Setting up the GL-AR750S-Ext or GL-MV1000 Travel Router

If you are using the GL-AR750S-Ext, you will need a Micro SD card that is formatted with an EXT file-system.  The GL-MV1000 has on-board storage that is sufficient for this configuration.

__GL-AR750S-Ext:__ From a linux host, insert the micro SD card, and run the following:

    mkfs.ext4 /dev/sdc1 <replace with the device representing your sdcard>

Insert the SD card into the router.  It will mount at `/mnt/sda1`, or `/mnt/sda` if you did not create a partition, but formatted the whole card.

You will need to enable root ssh access to your router.  The best way to do this is by adding an SSH key.  Don't allow password access over ssh.  We already created an SSH key for our Bastion host, so we'll use that.  If you want to enable SSH access from your workstation as well, then follow the same instructions to create/add that key as well.  We will also set the router IP address to `10.11.11.1`

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

    ssh root@<router IP>

If you are using the `GL-AR750S-Ext`, note that I create a symbolic link from the SD card to /data so that the configuration matches the configuration of the `GL-MV1000`.  Since I have both, this keeps things consistent.

    ln -s /mnt/sda1 /data        # This is not necessary for the GL-MV1000

Now we will enable TFTP and PXE: (The VMs will boot via iPXE, and the KVM hosts will boot via PXE/UEFI, __I'm hoping to get iPXE working with Intel NUCs too... but that is WIP__)

    mkdir -p /data/tftpboot/ipxe/templates

    uci add_list dhcp.lan.dhcp_option="6,10.11.11.10,8.8.8.8,8.8.4.4"
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
    uci set dhcp.uefi.filename='tag:efi64,tag:!ipxe,BOOTX64.EFI'
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

    exit

That's a lot of `uci` commands that we just did.  I won't drain the list, but I will explain at a high level, because some of this is not well documented by OpenWRT, and is the result of a LOT of Googling on my part.

* `uci add_list dhcp.lan.dhcp_option="6,10.11.11.10,8.8.8.8,8.8.4.4"`  This is setting DHCP option 6, (DNS Servers), it represents the list of DNS servers that the DHCP client should use for name resolution.
* `uci set dhcp.efi64_boot_1=match`  This series of commands creates a DHCP match for DHCP option 60 in the request.  If the vendor class identifier is `7` or `9`, then the match variable, (`networkid`), is set to `efi64` which is arbitrary, but matchable in the `boot` sections which come after.
* `uci set dhcp.ipxe_boot=userclass`  This series of commands looks for a userclass of `iPXE` in the DHCP request and sets the `networkid` variable to `ipxe`.
* `uci set dhcp.uefi=boot` This series of commands looks for a `networkid` match against either `efi64` or `ipxe` and sends the appropriate PXE response back to the client.

With the router configured, it's now time to copy over the files for iPXE.

This project has some files already prepared for you.  They are located in ./Provisioning/iPXE.

|||
|-|-|
| boot.ipxe | This is the initial iPXE bootstrap file.  It has logic in it to look for a file with the booting host's MAC address.  Otherwise it pulls the default.ipxe file. |
| fcos-okd4.ipxe | This is the iPXE file that will boot an FCOS image.  The deployment scripts that you will use later, will configure a copy of this file for booting Bootstrap, Master, or Worker OKD nodes. |
| default.ipxe | This file will initiate a kickstart install of CentOS 7 for non-OKD hosts. __This is not working yet__ |
| grub.cfg | Until I get iPXE working with intel NUC, we'll be using UEFI |

From the root directory of this project, execute the following:

    mkdir tmp-work
    cp ./Provisioning/iPXE/* ./tmp-work
    for i in $(ls ./tmp-work)
    do
        sed -i "s|%%INSTALL_URL%%|${INSTALL_URL}|g" ./tmp-work/${i}
    done
    scp ./tmp-work/boot.ipxe root@${LAB_GATEWAY}:/data/tftpboot/boot.ipxe
    scp ./tmp-work/default.ipxe root@${LAB_GATEWAY}:/data/tftpboot/ipxe/default.ipxe
    scp ./tmp-work/grub.cfg root@${LAB_GATEWAY}:/data/tftpboot
    mkdir -p ${OKD4_LAB_PATH}/ipxe-templates
    cp ./tmp-work/fcos-okd4.ipxe ${OKD4_LAB_PATH}/ipxe-templates/fcos-okd4.ipxe
    cp ./tmp-work/okd-lb.ipxe ${OKD4_LAB_PATH}/ipxe-templates/okd-lb.ipxe
    rm -rf ./tmp-work

Finally, copy the UEFI PXE boot files to the router:

    scp ${INSTALL_ROOT}/centos/EFI/BOOT/grubx64.efi root@${LAB_GATEWAY}:/data/tftpboot/
    scp ${INSTALL_ROOT}/centos/EFI/BOOT/BOOTX64.EFI root@${LAB_GATEWAY}:/data/tftpboot/
    ssh root@${LAB_GATEWAY} "mkdir /data/tftpboot/networkboot"
    scp ${INSTALL_ROOT}/centos/isolinux/vmlinuz root@${LAB_GATEWAY}:/data/tftpboot/networkboot
    scp ${INSTALL_ROOT}/centos/isolinux/initrd.img root@${LAB_GATEWAY}:/data/tftpboot/networkboot

__Your router is now ready to PXE boot hosts.__

Continue on to set up your Nexus: [Sonatype Nexus Setup](Nexus_Config.md)
