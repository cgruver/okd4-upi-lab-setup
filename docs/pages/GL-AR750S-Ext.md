## Setting up the GL-AR750S-Ext Travel Router for PXE Boot and OS install

At this point, we need a micro-sd card that is formatted with an EXT file-system.  I used ext4.

    mkfs.ext4 /dev/sdc1 <replace with the device representing your sdcard>

Insert the SD card into the router.  It will mount at `/mnt/sda1`, or `/mnt/sda` if you did not create a partition, but formatted the whole card.

You will need to enable root ssh access to your router.  The best way to do this is by adding an SSH key.  If you don't already have an ssh key, create one: (Take the defaults for all of the prompts, don't set a key password)

    ssh-keygen
    <Enter>
    <Enter>
    <Enter>

1. Login to your router with a browser: `https://<router IP>`
2. Expand the `MORE SETTINGS` menu on the left, and select `Advanced`
3. Login to the Advanced Administration console
4. Expand the `System` menu at the top of the screen, and select `Administration`
   1. Ensure that the Dropbear Instance `Interface` is set to `unspecified` and that the `Port` is `22`
   2. Ensure that the following are __NOT__ checked:
      * `Password authentication`
      * `Allow root logins with password`
      * `Gateway ports`
   3. Paste your public SSH key into the `SSH-Keys` section at the bottom of the page
      * Your public SSH key is likely in the file `$HOME/.ssh/id_rsa.pub`
   4. Click `Save & Apply`

Now that we have enabled SSH access to the router, we will login and complete our setup from the command-line.

First we need to set up some file paths and populate them with boot & install files:

    ssh root@<router IP>
    mkdir -p /mnt/sda1/tftpboot/networkboot
    mkdir -p /mnt/sda1/install/centos
    exit

Download the CentOS minimal install image:

    wget https://buildlogs.centos.org/rolling/7/isos/x86_64/CentOS-7-x86_64-Minimal.iso

Mount the ISO file, and copy the appropriate files to your router:

I'm using MacOS which is a little annoying when mounting an ISO generated with `genisoimage`:

    mkdir /tmp/centos
    hdiutil attach -nomount ~/Download/CentOS-7-x86_64-Minimal.iso

You will see output similar to:

    /dev/disk2          	FDisk_partition_scheme
    /dev/disk2s2        	0xEF                        

Mount the ISO filesystem:

    mount -t cd9660 /dev/disk2 /tmp/centos/

If you are using a Linux OS you should be able to mount it with:

    mkdir /tmp/centos
    mount /path/to/CentOS-7-x86_64-Minimal.iso /tmp/centos -o loop

Copy the PXE boot files: (substitute your router IP and path to tftpboot & install)

    cd /tmp/centos/EFI/BOOT
    scp BOOTX64.EFI root@10.11.11.1:/mnt/sda1/tftpboot

    cd /tmp/centos/images/pxeboot
    scp initrd.img root@10.11.11.1:/mnt/sda1/tftpboot/networkboot
    scp vmlinuz root@10.11.11.1:/mnt/sda1/tftpboot/networkboot

    cd /tmp
    scp -r centos root@10.11.11.1:/mnt/sda1/install

    cd
    umount /dev/disk2
    hdiutil detach /dev/disk2

We have one more step, and that is the grub.cfg file.  I have provided one for you in the `PXE_Setup` folder within this project.  It needs to be configured with the IP address of your HTTP server that is hosting your Install repository, kickstart, firstboot, and hostconfig files.  See [Host OS Provisioning](Setup_Env.md)

    cd PXE_Setup
    mkdir tmp_work
    cp grub.cfg tmp_work
    cd tmp_work
    sed -i "s|%%HTTP_IP%%|10.11.11.1|g" ./grub.cfg  # Replace with the IP address of your router.
    scp grub.cfg root@10.11.11.1:/mnt/sda1/tftpboot # Replace with the IP address of your router.
    cd ..
    rm -rf tmp_work

Now, we will enable the tftp server and instruct the DHCP server to send PXE boot info:

    ssh root@10.11.11.1  # Replace with the IP address of your router.
    uci set dhcp.@dnsmasq[0].enable_tftp=1
    uci set dhcp.@dnsmasq[0].tftp_root=/mnt/sda1/tftpboot
    uci set dhcp.@dnsmasq[0].dhcp_boot=BOOTX64.EFI
    uci commit dhcp
    /etc/init.d/dnsmasq restart
    exit

Assuming that you have followed the steps here: [Host OS Provisioning](Setup_Env.md), then we are ready to [PXE Boot a bare metal host](Install_Bare_Metal.md)
