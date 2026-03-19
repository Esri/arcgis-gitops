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

# The script initializes a Red Hat Enterprise Linux 9 (RHEL 9) instance for ArcGIS Notebook Server: 
#
# * Grows the root partition to utilize all available disk space
# * Installs Azure CLI
# * Disables firewalld and enables nftables with iptables compatibility
# * Installs Docker CE
# * If gpu_ready attribute is `true`, the script also installs:
# * * Development Tools
# * * Compute-only NVIDIA Driver open kernel modules (https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/)
# * * CUDA Toolkit (https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
# * * NVIDIA Container Toolkit (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

set -e
set -x  # This will print every single command to the log before running it

# Grow the root partition to utilize all available disk space
echo "Growing partition 4..."
sudo growpart /dev/sda 4
echo "Resizing LVM Physical Volume..."
sudo pvresize /dev/sda4
echo "Extending Logical Volume..."

# Extend the /usr logical volume first 
sudo lvextend -L +40G /dev/mapper/rootvg-usrlv
sudo xfs_growfs /usr

# Then extend the root logical volume with the remaining free space
sudo lvextend -l +100%FREE /dev/mapper/rootvg-rootlv
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

# Install Docker CE

DOCKER_CE_PACKAGE_VERSION="3:$DOCKER_VERSION-1.el9"
DOCKER_CE_CLI_PACKAGE_VERSION="1:$DOCKER_VERSION-1.el9"

# Disable firewalld and enable nftables with iptables compatibility.
sudo dnf install -y iptables-services
sudo systemctl disable firewalld || true
sudo systemctl disable nftables || true
sudo systemctl enable --now iptables

# Install Docker CE
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y docker-ce-$DOCKER_CE_PACKAGE_VERSION docker-ce-cli-$DOCKER_CE_CLI_PACKAGE_VERSION containerd.io docker-buildx-plugin docker-compose-plugin
sudo mkdir -p /docker-data # Create the data-root directory for Docker in the root partition
echo '{"iptables": true, "data-root": "/docker-data"}' | sudo tee /etc/docker/daemon.json
sudo systemctl enable --now docker

# Reject Docker containers access to EC2 instance metadata IP address.
sudo iptables --insert DOCKER-USER --destination 169.254.169.254 --jump REJECT --verbose
# Save the iptables rules
sudo iptables-save > /etc/sysconfig/iptables

# If gpu_ready is true, install NVIDIA Driver, CUDA Toolkit and NVIDIA Container Toolkit
if [ "$GPU_READY" == "true" ]; then
  # Install gcc
  sudo dnf groupinstall -y "Development Tools"

  # Install NVIDIA Driver & CUDA Toolkit
  sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
  sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo
  sudo dnf clean expire-cache
  sudo dnf module enable -y nvidia-driver:open-dkms
  # Headless install of NVIDIA Driver for open kernel modules
  sudo dnf install -y nvidia-driver-cuda kmod-nvidia-open-dkms 
  
  # Install CUDA Toolkit and NVIDIA GDS
  sudo dnf install -y cuda-toolkit nvidia-gds

  # Install NVIDIA Container Toolkit
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
  sudo dnf install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
fi

df -h

exit 0