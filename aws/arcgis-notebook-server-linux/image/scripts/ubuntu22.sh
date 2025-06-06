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

# The script initializes an Ubuntu 22.04 instance for ArcGIS Notebook Server: 
#
# * Installs Docker CE (https://docs.docker.com/engine/install/ubuntu/)
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

sudo apt-get install -y jq

# Get the parameters from the JSON string
GPU_READY=$(echo $attributes | jq -r '.gpu_ready')

# Add Docker's official GPG key:
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y

# Install Docker CE
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if [ "$GPU_READY" == "true" ]; then
  # Install gcc
  sudo apt-get install -y build-essential gcc-12

  # Install NVIDIA Driver
  sudo apt-get install -y linux-headers-$(uname -r)

  cd /tmp
  wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
  sudo dpkg -i cuda-keyring_1.1-1_all.deb
  sudo apt-get update -y

  sudo apt-get install -y libnvidia-compute-575 nvidia-dkms-575-open nvidia-utils-575

  # Install CUDA Toolkit
  sudo apt-get install -y cuda-toolkit nvidia-gds

  # Install NVIDIA Container Toolkit
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sudo apt-get install -y nvidia-container-toolkit 
  sudo nvidia-ctk runtime configure --runtime=docker 
fi
