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

set -euo pipefail

fail() { echo "ArcGIS data disk: $*" >&2; exit 1; }
read -r -a services <<< "${ARCGIS_DATA_SERVICES:-arcgisserver tomcat_arcgis}"
[[ ${#services[@]} -gt 0 ]] || fail "At least one data disk service is required."
for service in "${services[@]}"; do
    [[ "$service" =~ ^[a-zA-Z0-9_-]+$ ]] || fail "Invalid data disk service name: $service."
done
identity=/etc/arcgis-data-disk.uuid
fresh=0
staging=
fstab_tmp=
cleanup() {
    if [[ -n "$staging" ]]; then
        if findmnt -rn -M "$staging" >/dev/null; then umount "$staging"; fi
        rmdir "$staging"
    fi
    if [[ -n "$fstab_tmp" ]]; then rm -f -- "$fstab_tmp"; fi
}
trap cleanup EXIT
[[ ! -L /opt && ( ! -e /opt || -d /opt ) ]] || fail "/opt must be a real directory."
opt_entries=$(awk '$1 !~ /^#/ && $2 == "/opt" { count++ } END { print count+0 }' /etc/fstab)
[[ "$opt_entries" -le 1 ]] || fail "Multiple /opt entries in fstab."
mount_options=defaults
opt_options=$(awk '$1 !~ /^#/ && $2 == "/opt" { print $4 }' /etc/fstab)
IFS=',' read -r -a source_options <<< "$opt_options"
for option in "${source_options[@]}"; do
    case "$option" in
        nodev|dev|nosuid|suid|noexec|exec|ro|rw) mount_options+=",$option" ;;
    esac
done
if [[ -f "$identity" ]]; then
    uuid=$(cat "$identity")
    mapfile -t disks < <(blkid -t "UUID=$uuid" -o device)
    [[ ${#disks[@]} -eq 1 ]] || fail "Expected exactly one saved data filesystem $uuid."
    device=${disks[0]}
    awk -v source="UUID=$uuid" '$1 !~ /^#/ && $2 == "/opt" && $1 != source { exit 1 }' /etc/fstab ||
        fail "Conflicting /opt entry in fstab."
else
    if [[ -n "${ARCGIS_DATA_VOLUME_ID:-}" ]]; then
        serial=${ARCGIS_DATA_VOLUME_ID//-/}
        mapfile -t disks < <(lsblk -dnro PATH,SERIAL | awk -v serial="$serial" '$2 == serial { print $1 }')
        if [[ ${#disks[@]} -eq 1 ]]; then
            device=${disks[0]}
        elif [[ ${#disks[@]} -eq 0 && -b /dev/xvdf ]]; then
            device=/dev/xvdf
        else
            fail "Expected one EBS disk matching $ARCGIS_DATA_VOLUME_ID."
        fi
    else
        device=${ARCGIS_DATA_DEVICE:?Set the explicit data disk device.}
    fi
    device=$(readlink -f "$device") || fail "Could not resolve the data device."
    [[ -b "$device" ]] || fail "Device $device does not exist."
    [[ "$(lsblk -dnro TYPE "$device")" == disk ]] || fail "Expected a whole data disk."
    [[ "$(lsblk -nrpo NAME "$device" | wc -l)" -eq 1 ]] || fail "Data disk has partitions; refusing to format."
    [[ -z "$(lsblk -nro MOUNTPOINT "$device")" ]] || fail "Data disk is already mounted."
    [[ -z "$(wipefs -n --noheadings "$device")" ]] || fail "Data disk has signatures; refusing to format."
    [[ ! -e /opt/arcgis ]] || fail "Source image already contains ArcGIS; existing deployments require a reviewed migration."
    [[ ! -e /etc/fstab.arcgis-before-opt ]] || fail "An earlier /opt initialization backup exists without a saved disk identity."
    mounts=$(findmnt -rn -o TARGET)
    if awk '$0 ~ "^/opt/" { found=1 } END { exit !found }' <<< "$mounts"; then
        fail "/opt contains nested mounts; refusing to copy them."
    fi
    fresh=1
    mkfs.ext4 -L ArcGISData "$device"
    uuid=$(blkid -s UUID -o value "$device")
    [[ -n "$uuid" ]] || fail "Formatted disk has no UUID."
fi

[[ "$(blkid -s TYPE -o value "$device")" == ext4 ]] || fail "Expected the baked ext4 data filesystem."
if [[ "$fresh" == 1 ]]; then
    staging=$(mktemp -d /mnt/arcgis-opt.XXXXXX)
    mount "$device" "$staging"
    if [[ -d /opt ]]; then cp -a -- /opt/. "$staging/"; fi
    umount "$staging"
    rmdir "$staging"
    staging=
    if findmnt -rn -M /opt >/dev/null; then umount /opt; fi
fi
mkdir -p /opt
if findmnt -rn -M /opt >/dev/null; then
    [[ "$(findmnt -rn -M /opt -o UUID)" == "$uuid" ]] || fail "/opt is mounted from another disk."
else
    [[ ! -e /opt/arcgis ]] || fail "Unmounted /opt contains an OS-disk ArcGIS installation."
    mount -o "$mount_options" "$device" /opt
fi
[[ "$(findmnt -rn -M /opt -o UUID)" == "$uuid" ]] || fail "/opt mount verification failed."
if ! awk -v source="UUID=$uuid" '$1 == source && $2 == "/opt" { found=1 } END { exit !found }' /etc/fstab; then
    if [[ "$fresh" == 1 ]]; then cp -a -- /etc/fstab /etc/fstab.arcgis-before-opt; fi
    fstab_tmp=$(mktemp /etc/fstab.arcgis.XXXXXX)
    cp -a -- /etc/fstab "$fstab_tmp"
    awk '$1 !~ /^#/ && $2 == "/opt" { print "# Replaced by ArcGIS data disk: " $0; next } { print }' /etc/fstab > "$fstab_tmp"
    printf 'UUID=%s /opt ext4 %s 0 2\n' "$uuid" "$mount_options" >> "$fstab_tmp"
    mv -f -- "$fstab_tmp" /etc/fstab
    fstab_tmp=
fi
if [[ "$fresh" == 1 ]]; then printf '%s\n' "$uuid" > "$identity"; fi
resize2fs "$device"
if [[ "${ARCGIS_VERIFY_PORTAL:-0}" == 1 ]]; then
    portal_data=/opt/arcgis/portal/usr/arcgisportal
    [[ -d "$portal_data" && ! -L "$portal_data" ]] || fail "Portal's default local data directory is missing."
    [[ "$(findmnt -rn -T "$portal_data" -o UUID)" == "$uuid" ]] ||
        fail "Portal data is not on the intended /opt filesystem."
fi
if [[ "${ARCGIS_VERIFY_SERVER:-0}" == 1 ]]; then
    server_dir=/opt/arcgis/server
    [[ -d "$server_dir" && ! -L "$server_dir" ]] || fail "ArcGIS Server installation directory is missing."
    [[ "$(findmnt -rn -T "$server_dir" -o UUID)" == "$uuid" ]] ||
        fail "ArcGIS Server is not on the intended /opt filesystem."
fi
if [[ "$0" != /usr/local/sbin/arcgis-data-disk ]]; then
    install -m 0755 "$0" /usr/local/sbin/arcgis-data-disk
fi
service_units=$(printf '%s.service ' "${services[@]}")
cat > /etc/systemd/system/arcgis-data-disk.service <<UNIT
[Unit]
Description=Verify and grow the ArcGIS data filesystem
RequiresMountsFor=/opt
Before=$service_units
[Service]
Type=oneshot
Environment="ARCGIS_DATA_SERVICES=${services[*]}"
ExecStart=/bin/bash /usr/local/sbin/arcgis-data-disk
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
for service in "${services[@]}"; do
    mkdir -p "/etc/systemd/system/$service.service.d"
    printf '[Unit]\nRequires=arcgis-data-disk.service\nAfter=arcgis-data-disk.service\nRequiresMountsFor=/opt\n' \
        > "/etc/systemd/system/$service.service.d/data-disk.conf"
done
systemctl daemon-reload
systemctl enable arcgis-data-disk.service
echo "Verified ArcGIS application filesystem $uuid on $device at /opt."
