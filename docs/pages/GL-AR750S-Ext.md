## Setting up the GL-AR750S-Ext or GL-MV1000 Travel Router

If you are using the GL-AR750S-Ext, you will need a Micro SD card that is formatted with an EXT file-system.  The GL-MV1000 has on-board storage that is sufficient for this configuration.

__GL-AR750S-Ext:__

    mkfs.ext4 /dev/sdc1 <replace with the device representing your sdcard>

Insert the SD card into the router.  It will mount at `/mnt/sda1`, or `/mnt/sda` if you did not create a partition, but formatted the whole card.

You will need to enable root ssh access to your router.  The best way to do this is by adding an SSH key.  Don't allow password access over ssh.  We already created an SSH key for our Bastion host, so we'll use that.  If you want to enable SSH access from your workstation as well, then follow the same instructions to create/add that key as well.  We will also set the router IP address to `10.11.11.1`

1. Login to your router with a browser: `https://<router IP>`
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

Now we will enable TFTP and iPXE:

    mkdir -p /data/tftpboot/ipxe/templates

    uci set dhcp.@dnsmasq[0].enable_tftp=1
    uci set dhcp.@dnsmasq[0].tftp_root=/data/tftpboot
    uci set dhcp.@dnsmasq[0].dhcp_boot=boot.ipxe
    uci add_list dhcp.lan.dhcp_option="6,10.11.11.10,8.8.8.8,8.8.4.4"
    uci commit dhcp
    /etc/init.d/dnsmasq restart

    exit

With the router configured, it's now time to copy over the files for iPXE.


Next, we will configure DNS: [DNS Setup](DNS_Config.md)
