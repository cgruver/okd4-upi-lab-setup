## Installing or reinstalling a NUC via iPXE

__Note:__ If you would rather manually install your KVM hosts, then follow this guide: [KVM Host Manual Install](KVM_Host_Install.md)

The installation on a bare metal host will work like this:

1. The host will power on and find no bootable OS
1. The host will attempt a network boot by requesting a DHCP address and PXE boot info
   * The DHCP server will issue an IP address and direct the host to the PXE boot file on the TFTP boot server
1. The host will retrieve the `boot.ipxe` file from the TFTP boot server
1. The `boot.ipxe` script will then retrieve an iPXE script name from the MAC address of the host.
1. The host will begin booting:
   1. The host will retrieve the `vmlinuz`, and `initrd` files from the HTTP install server
   1. The host will load the kernel and init-ram
   1. The host will retrieve the kickstart file or ignition config file depending on the install type.
1. The host should now begin an unattended install.
1. The host will reboot and run the `firstboot.sh` script, if one is configured.  (selinux is temporarily disabled to allow this script to run)
1. The host is now ready to use!

There are a couple of things that we need to put in place to get started.

First we need to flip the NUC over and get the MAC address for the wired NIC.  You also need to know whether you have NVME or SATA SSDs in the NUC.

I have provided a helper script, `DeployKvmHost.sh` that will configure the files for you.

    DeployKvmHost.sh -h=kvm-host01 -m=1c:69:7a:02:b6:c2 -d=nvme0n1 # Example with 1 NVME SSD
    DeployKvmHost.sh -h=kvm-host01 -m=1c:69:7a:02:b6:c2 -d=sda,sdb # Example with 2 SATA SSD

Finally, make sure that you have created DNS `A` and `PTR` records.  [DNS Setup](DNS_Config.md)

We are now ready to plug in the NUC and boot it up.

__Caution:__  This is the point at which you might have to attach a keyboard and monitor to your NUC.  We need to ensure that the BIOS is set up to attempt a Network Boot with UEFI, not legacy.  You also need to ensure that `Secure Boot` is disabled in the BIOS since we are not explicitly trusting the boot images.

__Take this opportunity to apply the latest BIOS to your NUC__

Tools URL: https://downloadcenter.intel.com/download/30090/Intel-Aptio-V-UEFI-Firmware-Integrator-Tools

You won't need the keyboard or mouse again, until it's time for another BIOS update...  Eventually we'll figure out how to push those from the OS too.  ;-)

The last thing that I've prepared for you is the ability to reinstall your OS.

### Re-Install your NUC host

__*I have included a very dangerous script in this project.*__  If you follow all of the setup instructions, it will be installed in `/root/bin/rebuildhost.sh` of your host.

The script is a quick and dirty way to brick your host so that when it reboots, it will force a Network Install.

The script will destroy your boot partitions and wipe the MBR in the installed SSD drives.  For example:

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
