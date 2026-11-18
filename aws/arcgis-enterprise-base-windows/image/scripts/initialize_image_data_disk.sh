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
if (( $# < 2 || $# > 4 )); then
    echo "Usage: $0 INSTANCE_ID REGION [initialize|prepare] [application|fileserver]" >&2
    exit 1
fi
instance_id=$1
region=$2
stage=${3:-initialize}
role=${4:-application}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case "$stage" in
    initialize) script="$script_dir/initialize_data_disk.ps1" ;;
    prepare) script="$script_dir/prepare_image_data_disk.ps1" ;;
    *) echo "Unsupported image disk stage: $stage." >&2; exit 1 ;;
esac
case "$role" in
    application|fileserver) ;;
    *) echo "Unsupported image role: $role." >&2; exit 1 ;;
esac
volume_id=$(aws ec2 describe-instances --region "$region" --instance-ids "$instance_id" \
    --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='/dev/sdf'].Ebs.VolumeId | [0]" --output text)
[[ "$volume_id" =~ ^vol-[0-9a-f]+$ ]] || { echo "Missing /dev/sdf EBS volume." >&2; exit 1; }
parameters=$(mktemp)
trap 'rm -f "$parameters"' EXIT
encoded=$(iconv -f UTF-8 -t UTF-16LE "$script" | base64 -w0)
arguments="-VolumeId '$volume_id'"
if [[ "$stage" == prepare && "$role" == application ]]; then
    arguments+=" -ApplicationImage"
fi
command="\$ErrorActionPreference='Stop'; \$script=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$encoded')); [IO.File]::WriteAllText('C:\\Windows\\Temp\\arcgis-data-disk.ps1',\$script); & 'C:\\Windows\\Temp\\arcgis-data-disk.ps1' $arguments"
jq -n --arg command "$command" '{commands:[$command], executionTimeout:["600"]}' > "$parameters"
command_id=$(aws ssm send-command --region "$region" --instance-ids "$instance_id" \
    --document-name AWS-RunPowerShellScript --parameters "file://$parameters" --query Command.CommandId --output text)
for ((attempt=0; attempt<150; attempt++)); do
    if result=$(aws ssm get-command-invocation --region "$region" --command-id "$command_id" --instance-id "$instance_id" --output json 2>&1); then
        status=$(jq -r .Status <<< "$result")
        case "$status" in
            Success) jq -r .StandardOutputContent <<< "$result"; exit 0 ;;
            Pending|InProgress|Delayed) ;;
            *) jq -r '.Status,.StandardOutputContent,.StandardErrorContent' <<< "$result" >&2; exit 1 ;;
        esac
    elif [[ "$result" != *InvocationDoesNotExist* ]]; then
        echo "$result" >&2
        exit 1
    fi
    sleep 5
done
echo "Data disk setup timed out: $command_id." >&2
exit 1
