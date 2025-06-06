#!/bin/bash

# Copyright 2025 Esri
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

# The script initializes a Red Hat Enterprise Linux 8 (RHEL 8) instance for ArcGIS Notebook Server: 
#
# * Disables firewalld and enables nftables with iptables compatibility
# * Installs Docker CE
# * If gpu_ready attribute is `true`, the script also installs:
# * * Development Tools
# * * Compute-only NVIDIA Driver open kernel modules (https://docs.nvidia.com/datacenter/tesla/driver-installation-guide/)
# * * CUDA Toolkit (https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
# * * NVIDIA Container Toolkit (https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

JSON_ATTRIBUTES_PARAMETER='<json_attributes_parameter>'

# Get the script input parameters in JSON format from SSM Parameter Store
attributes=$(aws ssm get-parameter --name $JSON_ATTRIBUTES_PARAMETER --query 'Parameter.Value' --with-decryption --output text)

if [ $? -ne 0 ]; then
  echo "Error: Failed to retrieve '$JSON_ATTRIBUTES_PARAMETER' SSM parameter."
  exit 1
fi

sudo dnf install -y jq

# Get the parameters from the JSON string
GPU_READY=$(echo $attributes | jq -r '.gpu_ready')

# Disable firewalld and enable nftables with iptables compatibility.
sudo dnf install -y iptables-services
sudo systemctl disable firewalld || true
sudo systemctl disable nftables || true
sudo systemctl enable --now iptables

# Install Docker CE
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo '{"iptables": true}' | sudo tee /etc/docker/daemon.json
sudo systemctl enable --now docker

if [ "$GPU_READY" == "true" ]; then
  # Install gcc
  sudo dnf groupinstall -y "Development Tools"

  # Install NVIDIA Driver & CUDA Toolkit
  sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
  sudo subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms
  sudo subscription-manager repos --enable=rhel-8-for-x86_64-baseos-rpms
  sudo subscription-manager repos --enable=codeready-builder-for-rhel-8-x86_64-rpms
  sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
  sudo dnf clean expire-cache
  sudo dnf module enable -y nvidia-driver:open-dkms
  # Headless install of NVIDIA Driver for open kernel modules
  sudo dnf install -y nvidia-driver-cuda kmod-nvidia-open-dkms 
  nvidia-smi
  # Install CUDA Toolkit and NVIDIA GDS
  sudo dnf install -y cuda-toolkit nvidia-gds

  # Install NVIDIA Container Toolkit
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
  sudo dnf install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
fi