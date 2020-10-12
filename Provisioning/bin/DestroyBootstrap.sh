#!/bin/bash

# Destroy the VM
virsh destroy okd4-bootstrap
virsh undefine okd4-bootstrap
virsh pool-destroy okd4-bootstrap
virsh pool-undefine okd4-bootstrap
rm -rf /VirtualMachines/okd4-bootstrap
