## Installing or reinstalling a NUC via iPXE

__Note:__ If you would rather manually install your KVM hosts, then follow this guide: [KVM Host Manual Install](KVM_Host_Install.md)

The installation on a bare metal host will work like this:

1. The host will power on and find no bootable OS
1. The host will attempt a network boot by requesting a DHCP address and PXE boot info
   * The DHCP server will issue an IP address and direct the host to the PXE boot file on the TFTP boot server
1. The host will retrieve the `boot.ipxe` file from the TFTP boot server
1. The `boot.ipxe` script will either retrieve an iPXE script name from the MAC address of the host, or it will retrieve `default.ipxe`
1. The host will begin booting:
   1. The host will retrieve the `vmlinuz`, and `initrd` files from the HTTP install server
   1. The host will load the kernel and init-ram
   1. The host will retrieve the kickstart file or ignition config file depending on the install type.
1. For Intel NUC hosts the kickstart file has a pre-execution phase that does a couple of things:
   1. It identifies whether or not the system has 1 or 2 SSDs installed and creates the appropriate partition information.
   1. It identifies the active NIC, extracts its MAC address, and then retrieves a file named after the MAC address from the install server.  This file contains environment variables that will be injected into kickstart to set up the host's network configuration.  The network configuration will create a bridge device named `br0` and connect the physical network device to the bridge.  This configuration also supports 2 NICs in a physical host.
1. The host should now begin an unattended install.
1. The host will reboot and run the `firstboot.sh` script.  (selinux is temporarily disabled to allow this script to run)
1. The host is now ready to use!

There are a couple of things that we need to put in place to get started.

First we need to flip the NUC over and get the MAC address for the wired NIC, and then create a file with the MAC address replacing the `:` characters with `-`.

Assuming your MAC is: `1C:69:7A:02:B6:C2` you will create a file named `1c-69-7a-02-b6-c2` and populate it with something like this: (There is an example file in this project under `./Provisioning/guest_install/hostconfig/1c-69-7a-02-b6-c2`)

    export NIC_02=enp60s0u1                         # The device name of your second NIC, if present
    export GATEWAY_01=10.11.11.1                    # Your primary network Router IP
    export IP_01=10.11.11.200                       # The IP you want this host to have on the primary network
    export IP_02=10.11.12.200                       # The IP you want this host to have on the storage network, if NIC_02 exists.
    export NAME_SERVER=10.11.11.10                  # Your DNS Server
    export NETMASK_01=255.255.255.0                 # Your primary network Netmask
    export NETMASK_02=255.255.255.0                 # Your storage network Netmask
    export HOST_NAME=kvm-host01.your.domain.com     # The FQDN that you want this host to have

Now, push that file to your install HTTP server:

    scp 1c697a02b6c2 root@${INSTALL_HOST}:${INSTALL_ROOT}/hostconfig

Finally, make sure that you have created DNS `A` and `PTR` records.  [DNS Setup](DNS_Config.md)

We are now ready to plug in the NUC and boot it up.

__Caution:__  This is the point at which you might have to attach a keyboard and monitor to your NUC.  We need to ensure that the BIOS is set up to attempt a Network Boot with UEFI, not legacy.  You also need to ensure that `Secure Boot` is disabled in the BIOS.

__Take this opportunity to apply the latest BIOS to your NUC__

You won't need the keyboard or mouse again, until it's time for another BIOS update...  Eventually we'll figure out how to push those from the OS too.  ;-)

The last thing that I've prepared for you is the ability to reinstall your OS.

### Re-Install your NUC host

__*I have included a very dangerous script in this project.*__  If you follow all of the setup instructions, it will be installed in `/root/bin/rebuildhost.sh` of your host.

The script is a quick and dirty way to brick your host so that when it reboots, it will force a Network Install.

The script will destroy your boot partitions and wipe the MBR in the installed SSD drives.

Destroy boot partitions:

    umount /boot/efi
    umount /boot
    wipefs -a /dev/sda2
    wipefs -a /dev/sda1

Wipe MBR:

    dd if=/dev/zero of=/dev/sda bs=512 count=1
    dd if=/dev/zero of=/dev/sdb bs=512 count=1

Reboot:

    shutdown -r now

That's it!  Your host is now a Brick.  If your PXE environment is set up properly, then in a few minutes you will have a fresh OS install.

Go ahead a build out all of your KVM hosts are this point.  For this lab you need at least one KVM host with 64GB of RAM.  With this configuration, you will build an OKD cluster with 3 Master nodes which are also schedulable, (is that a word?), as worker nodes.  If you have two, then you will build an OKD cluster with 3 Master and 3 Worker nodes.

It is now time to deploy an OKD cluster: [Deploy OKD](DeployOKD.md)
