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
if (( $# < 2 || $# > 3 )); then
    echo "Usage: $0 INSTANCE_ID REGION [initialize|verify]" >&2
    exit 1
fi
instance_id=$1
region=$2
mode=${3:-initialize}
case "$mode" in
    initialize|verify) ;;
    *) echo "Unsupported Linux data disk mode: $mode." >&2; exit 1 ;;
esac
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$script_dir/initialize_data_disk.sh"
volume_id=$(aws ec2 describe-instances --region "$region" --instance-ids "$instance_id" \
    --query "Reservations[0].Instances[0].BlockDeviceMappings[?DeviceName=='/dev/sdf'].Ebs.VolumeId | [0]" --output text)
[[ "$volume_id" =~ ^vol-[0-9a-f]+$ ]] || { echo "Missing /dev/sdf EBS volume." >&2; exit 1; }
parameters=$(mktemp)
trap 'rm -f "$parameters"' EXIT
encoded=$(base64 -w0 "$script")
verify=0
[[ "$mode" != verify ]] || verify=1
command="printf '%s' '$encoded' | base64 -d > /tmp/arcgis-data-disk.sh && ARCGIS_DATA_VOLUME_ID='$volume_id' ARCGIS_VERIFY_PORTAL='$verify' bash /tmp/arcgis-data-disk.sh"
jq -n --arg command "$command" '{commands:[$command], executionTimeout:["600"]}' > "$parameters"
command_id=$(aws ssm send-command --region "$region" --instance-ids "$instance_id" \
    --document-name AWS-RunShellScript --parameters "file://$parameters" --query Command.CommandId --output text)
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
