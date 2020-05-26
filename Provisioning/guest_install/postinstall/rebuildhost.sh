#!/bin/bash

umount /boot/efi
umount /boot
wipefs -a /dev/sda2
wipefs -a /dev/sda1
dd if=/dev/zero of=/dev/sda bs=512 count=1
dd if=/dev/zero of=/dev/sdb bs=512 count=1
shutdown -r now

