#!/bin/bash

# Copyright 2026 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The script initializes a Red Hat Enterprise Linux 9 (RHEL 9) instance for base ArcGIS Enterprise.

set -e
set -x  # This will print every single command to the log before running it

# Grow the root partition to utilize all available disk space
echo "Growing partition 4..."
sudo growpart /dev/sda 4
echo "Resizing LVM Physical Volume..."
sudo pvresize /dev/sda4
echo "Extending Logical Volume..."
sudo lvextend -l +100%FREE /dev/mapper/rootvg-rootlv
echo "Expanding XFS Filesystem..."
sudo xfs_growfs /
echo "Final Disk Space:"
df -h /

# Install Azure CLI and AZNFS mount helper

# Clear out the failed repos
sudo rm -f /etc/yum.repos.d/azure-cli.repo /etc/yum.repos.d/microsoft-prod.repo
sudo dnf clean all

# Create the RHEL 9 specific repo file
# CRITICAL: RHEL 9 rejects Microsoft's metadata signature. 
# We disable the metadata check but keep the package check (gpgcheck=1) on.
sudo tee /etc/yum.repos.d/azure-cli.repo <<EOT
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/rhel/9/prod/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOT

# Refresh and Install
sudo dnf clean all
sudo dnf makecache

sudo dnf install -y azure-cli-$AZURE_CLI_VERSION* 
sudo dnf install -y nfs-utils aznfs

# Open ArcGIS Server ports in the firewall
sudo firewall-cmd --add-port={1098,6006,6080,6099,6443}/tcp --permanent

# Open Portal for ArcGIS ports in the firewall
sudo firewall-cmd --add-port={5701,5702,5703,7080,7443,7005,7099,7120,7220,7654,7820,7830,7840,11211,50432}/tcp --permanent

# Open ArcGIS Data Store ports in the firewall
sudo firewall-cmd --add-port={2443,4369,9220,9320,9820,9828,9829,9830,9831,9840,9850,9876,9900,25672,44369,45671,45672,29079-29090}/tcp --permanent

df -h

exit 0
