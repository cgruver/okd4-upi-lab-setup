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
    ln -s /mnt/sda1 /data
    mkdir -p /data/tftpboot/ipxe/templates

    uci set dhcp.@dnsmasq[0].enable_tftp=1
    uci set dhcp.@dnsmasq[0].tftp_root=/data/tftpboot
    uci set dhcp.@dnsmasq[0].dhcp_boot=boot.ipxe
    uci add_list dhcp.lan.dhcp_option="6,10.10.11.10,8.8.8.8,8.8.4.4"
    uci commit dhcp
    /etc/init.d/dnsmasq restart

    exit
