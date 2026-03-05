#!/bin/bash

set -e
set -x # Enable debug mode to print each command before execution

# Tell the kernel the disk size has changed
echo 1 | sudo tee /sys/class/block/sda/device/rescan

# Expand the partition entry in the partition table
sudo growpart /dev/sda 4

# Resize Physical Volume
sudo pvresize /dev/sda4

# Expand Logical Volume
sudo lvextend -l +100%FREE /dev/mapper/rootvg-rootlv  

#Expanding XFS Filesystem
sudo xfs_growfs /

# Print the disk usage after resizing
df -h
