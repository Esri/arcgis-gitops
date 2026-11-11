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

root_lv=$(readlink -f "$(findmnt -n -o SOURCE /)")
root_matches=()
while read -r candidate_vg candidate_lv; do
	if [[ -n "$candidate_lv" && $(readlink -f "$candidate_lv") == "$root_lv" ]]; then
		root_matches+=("$candidate_vg $candidate_lv")
	fi
done < <(sudo lvs --noheadings -o vg_name,lv_path)
if (( ${#root_matches[@]} != 1 )); then
	echo "Expected exactly one LVM logical volume matching root device $root_lv." >&2
	exit 1
fi
read -r root_vg root_lv <<< "${root_matches[0]}"
mapfile -t root_pvs < <(sudo pvs --noheadings -o pv_name --select "vg_name=$root_vg" | awk 'NF {print $1}')
if (( ${#root_pvs[@]} != 1 )); then
	echo "Expected exactly one physical volume in root volume group $root_vg." >&2
	exit 1
fi
root_pv=$(readlink -f "${root_pvs[0]}")
if [[ $(lsblk -dn -o TYPE "$root_pv") != part ]]; then
	echo "Expected a partition-backed root physical volume: $root_pv" >&2
	exit 1
fi
root_disk="/dev/$(lsblk -dn -o PKNAME "$root_pv" | xargs)"
root_partition=$(cat "/sys/class/block/$(basename "$root_pv")/partition")
if [[ $(lsblk -dn -o TYPE "$root_disk") != disk || ! "$root_partition" =~ ^[0-9]+$ ]]; then
	echo "Cannot resolve the root disk and partition for $root_pv." >&2
	exit 1
fi
echo "Growing root partition $root_partition on $root_disk..."
if grow_output=$(sudo growpart "$root_disk" "$root_partition" 2>&1); then
	echo "$grow_output"
else
	grow_status=$?
	echo "$grow_output"
	if [[ $grow_status -ne 1 || "$grow_output" != *NOCHANGE:* ]]; then
		exit "$grow_status"
	fi
fi
echo "Resizing LVM Physical Volume..."
sudo pvresize "$root_pv"
echo "Extending Logical Volume..."
free_extents=$(sudo vgs --noheadings -o vg_free_count "$root_vg" | xargs)
if [[ ! "$free_extents" =~ ^[0-9]+$ ]]; then
	echo "Cannot determine free extents in root volume group $root_vg." >&2
	exit 1
fi
if (( free_extents > 0 )); then
	sudo lvextend -l +100%FREE "$root_lv"
fi
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

# Waiting for Azure IMDS and RHUI to settle...
sleep 60

# Refresh the expired RHUI client certificate while ignoring BaseOS/AppStream repos
sudo dnf update -y --disablerepo='*' --enablerepo='rhui-microsoft-azure-rhel9' rhui-azure-rhel9 || \
sudo dnf update -y --disablerepo='*' --enablerepo='azure-cli' rhui-azure-rhel9

# Refresh and Install
sudo dnf clean all
for attempt in 1 2 3; do
	if sudo dnf makecache; then
		break
	fi
	if [ "$attempt" -eq 3 ]; then
		echo "dnf makecache failed after $attempt attempts." >&2
		exit 1
	fi
	echo "dnf makecache failed (attempt $attempt/3); retrying in 30 seconds..." >&2
	sudo dnf clean expire-cache
	sleep 30
done

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
