#!/bin/bash

set -e
set -x # Enable debug mode to print each command before execution

# Create the mount point directory if it doesn't exist
sudo mkdir -p $MOUNT_POINT

NETWORK_PATH="$STORAGE_ACCOUNT_NAME.file.core.windows.net:/$STORAGE_ACCOUNT_NAME/$FILE_SHARE_NAME"

sudo mount -t aznfs $NETWORK_PATH $MOUNT_POINT -o vers=4,minorversion=1,sec=sys,nconnect=4

# Add the mount to /etc/fstab for persistence if not already present
if ! grep -qs "$MOUNT_POINT" /etc/fstab; then
    echo "Adding $MOUNT_POINT to /etc/fstab for persistence..."
    echo "$NETWORK_PATH $MOUNT_POINT aznfs vers=4,minorversion=1,sec=sys,nconnect=4 0 0" | sudo tee -a /etc/fstab
else
    echo "$MOUNT_POINT is already present in /etc/fstab. Skipping fstab entry."
fi

df -h $MOUNT_POINT
