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

set -e
set -x # Enable debug mode to print each command before execution

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
rescan_path="/sys/class/block/$(basename "$root_disk")/device/rescan"
if [[ -e "$rescan_path" ]]; then
	echo 1 | sudo tee "$rescan_path"
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
sudo pvresize "$root_pv"
free_extents=$(sudo vgs --noheadings -o vg_free_count "$root_vg" | xargs)
if [[ ! "$free_extents" =~ ^[0-9]+$ ]]; then
	echo "Cannot determine free extents in root volume group $root_vg." >&2
	exit 1
fi
if (( free_extents > 0 )); then
	sudo lvextend -l +100%FREE "$root_lv"
fi
sudo xfs_growfs /

# Print the disk usage after resizing
df -h
