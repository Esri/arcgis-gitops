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

[[ -s /etc/arcgis-data-disk.uuid ]] || { echo 'Rebuild the Notebook image with data LUN 0 before deployment.' >&2; exit 1; }
ARCGIS_DATA_SERVICES='docker containerd' bash /usr/local/sbin/arcgis-data-disk
uuid=$(cat /etc/arcgis-data-disk.uuid)
[[ "$(findmnt -rn -M /opt -o UUID)" == "$uuid" ]]
[[ -d /opt/docker && ! -L /opt/docker ]]
[[ "$(findmnt -rn -T /opt/docker -o UUID)" == "$uuid" ]]
[[ "$(docker info --format '{{.DockerRootDir}}')" == /opt/docker ]]
echo "Verified Notebook /opt and Docker storage on data filesystem $uuid."