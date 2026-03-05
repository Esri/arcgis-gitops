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

# The script initializes an Ubuntu 24.04 instance for ArcGIS Notebook Server: 
#
# * Installs Docker CE (https://docs.docker.com/engine/install/ubuntu/)
# * If gpu_ready attribute is `true`, the script also installs:
# * * Development Tools
# * * Compute-only NVIDIA Driver open kernel modules (https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/)
# * * CUDA Toolkit (https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
# * * NVIDIA Container Toolkit (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

set -e
set -x  # This will print every single command to the log before running it

# Install Azure CLI

# 1. Get packages needed for the installation process
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 2. Download and install the Microsoft signing key
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
  gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

# 3. Add the Azure CLI software repository
echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: $(lsb_release -cs)
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

# 4. Install a specific version of Azure CLI
sudo apt-get update -y
# apt-cache policy azure-cli
sudo apt-get install -y azure-cli=$AZURE_CLI_VERSION-1~$(lsb_release -cs)

# Install AZNFS mount helper 

curl -sSL -O https://packages.microsoft.com/config/$(source /etc/os-release && echo "$ID/$VERSION_ID")/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y nfs-common aznfs

# Install Docker CE

DOCKER_CE_PACKAGE_VERSION="5:$DOCKER_VERSION-1~ubuntu.24.04~$(lsb_release -cs)"
DOCKER_CE_CLI_PACKAGE_VERSION="5:$DOCKER_VERSION-1~ubuntu.24.04~$(lsb_release -cs)"

# 1. Add Docker's official GPG key:
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 2. Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

# 3. Install Docker CE
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce=$DOCKER_CE_PACKAGE_VERSION docker-ce-cli=$DOCKER_CE_CLI_PACKAGE_VERSION containerd.io docker-buildx-plugin docker-compose-plugin

# Reject Docker containers access to the Azure VM metadata IP address.
sudo iptables --insert DOCKER-USER --destination 169.254.169.254 --jump REJECT --verbose

# Save the iptables rules
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
sudo iptables-save > /etc/iptables/rules.v4

# Install NVIDIA drivers, CUDA Toolkit, and NVIDIA Container Toolkit if gpu_ready is true
if [ "$GPU_READY" == "true" ]; then
  # Install gcc
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential gcc-12

  # Install NVIDIA Driver
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y linux-headers-$(uname -r)

  cd /tmp
  wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libnvidia-compute-575 nvidia-dkms-575-open nvidia-utils-575

  # Install CUDA Toolkit
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-toolkit nvidia-gds

  # Install NVIDIA Container Toolkit
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit 
  sudo nvidia-ctk runtime configure --runtime=docker 
fi

df -h

exit 0