#!/bin/bash

set -e
set -x # Enable debug mode to print each command before execution

# Tell the kernel the disk size has changed
echo 1 | sudo tee /sys/class/block/sda/device/rescan

# Attempt to grow the partition. 
# If it returns 1 (NOCHANGE), we treat it as a success (|| true).
sudo growpart /dev/sda 4 || [ $? -eq 1 ]

# Resize Physical Volume
sudo pvresize /dev/sda4

# Expand Logical Volume
sudo lvextend -l +100%FREE /dev/mapper/rootvg-rootlv || [ $? -eq 5 ] 

#Expanding XFS Filesystem
sudo xfs_growfs /

# Print the disk usage after resizing
df -h
