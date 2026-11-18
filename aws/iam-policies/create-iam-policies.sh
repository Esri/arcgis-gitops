#!/bin/bash

# Copyright 2025-2026 Esri
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
export AWS_PAGER=""

for dependency in aws jq; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'ERROR: Required command not found: %s\n' "$dependency" >&2
        exit 1
    fi
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd -- "$script_dir"
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

policies=(
    "ArcGISEnterpriseApplication|The policy for ArcGIS Enterprise applications management workflows"
    "ArcGISEnterpriseDestroy|The policy for destroying resources created by ArcGIS Enterprise infrastructure and application management workflows"
    "ArcGISEnterpriseImage|The policy for creating EC2 AMIs for ArcGIS Enterprise deployments"
    "ArcGISEnterpriseInfrastructure|The policy for ArcGIS Enterprise infrastructure management workflows"
    "ArcGISEnterpriseK8s|The policy for ArcGIS Enterprise on Kubernetes workflows"
    "ArcGISEnterpriseCore|The policy for enterprise-core-aws workflow"
    "ArcGISEnterpriseCoreDestroy|The policy for enterprise-core-aws-destroy workflow"
    "ArcGISEnterpriseK8sCluster|The policy for enterprise-k8s-cluster-aws workflow"
    "ArcGISEnterpriseK8sClusterDestroy|The policy for enterprise-k8s-cluster-aws-destroy workflow"
    "TerraformBackend|The policy for Terraform S3 backend"
)

for policy in "${policies[@]}"; do
    name=${policy%%|*}
    if ! jq -e -S -c -s '
        if length == 1 and (.[0] | type == "object") then .[0]
        else error("Expected one JSON policy object") end
    ' "$name.json" >"$work_dir/$name.json"; then
        printf 'ERROR: Invalid policy document: %s/%s.json\n' "$script_dir" "$name" >&2
        exit 1
    fi
done

aws sts get-caller-identity --output json >"$work_dir/identity.json"
if ! account_id=$(jq -er '.Account | select(type == "string" and test("^[0-9]{12}$"))' "$work_dir/identity.json") ||
    ! partition=$(jq -er '.Arn | split(":") | .[1] | select(test("^aws(-[a-z0-9-]+)?$"))' "$work_dir/identity.json"); then
    printf 'ERROR: Invalid AWS caller identity response.\n' >&2
    exit 1
fi

report_aws_error() {
    printf 'ERROR: %s\n' "$1" >&2
    cat "$work_dir/aws-error" >&2
    return 1
}

reconcile_policy() {
    local name="$1" description="$2" retry_create="${3:-true}"
    local arn="arn:$partition:iam::$account_id:policy/$name"
    local current_version local_document remote_document version_count oldest_version

    printf 'Checking policy: %s\n' "$arn"
    if aws iam get-policy --policy-arn "$arn" --output json \
        >"$work_dir/policy.json" 2>"$work_dir/aws-error"; then
        :
    elif grep -Fq '(NoSuchEntity) when calling the GetPolicy operation' "$work_dir/aws-error"; then
        if aws iam create-policy --policy-name "$name" --policy-document "file://$name.json" \
            --tags Key=ArcGISEnterpriseId,Value=arcgis --description "$description" --output json \
            >"$work_dir/created.json" 2>"$work_dir/aws-error"; then
            if ! jq -e --arg arn "$arn" '.Policy.Arn == $arn' "$work_dir/created.json" >/dev/null; then
                printf 'ERROR: Invalid creation response for policy %s; inspect its current state before retrying.\n' "$name" >&2
                return 1
            fi
            printf 'Created: %s\n' "$arn"
            return
        elif [[ "$retry_create" == true ]] &&
            grep -Fq '(EntityAlreadyExists) when calling the CreatePolicy operation' "$work_dir/aws-error"; then
            reconcile_policy "$name" "$description" false
            return
        else
            report_aws_error "Could not create policy $name."
            return 1
        fi
    else
        report_aws_error "Could not look up policy $name."
        return 1
    fi

    current_version=$(jq -er --arg arn "$arn" '
        if .Policy.Arn == $arn and
            (.Policy.DefaultVersionId | type == "string" and test("^v[1-9][0-9]*$"))
        then .Policy.DefaultVersionId else error("Invalid policy metadata") end
    ' "$work_dir/policy.json")
    if ! aws iam get-policy-version --policy-arn "$arn" --version-id "$current_version" --output json \
        >"$work_dir/version.json" 2>"$work_dir/aws-error"; then
        report_aws_error "Could not read default version $current_version of $name."
        return 1
    fi

    local_document=$(cat "$work_dir/$name.json")
    remote_document=$(jq -e -S -c '
        .PolicyVersion.Document |
        if type == "object" then . else error("Invalid default policy document") end
    ' "$work_dir/version.json")
    if [[ "$local_document" == "$remote_document" ]]; then
        printf 'Unchanged (reused): %s\n' "$arn"
        return
    fi

    if ! aws iam list-policy-versions --policy-arn "$arn" --output json \
        >"$work_dir/versions.json" 2>"$work_dir/aws-error"; then
        report_aws_error "Could not list versions of $name."
        return 1
    fi
    version_count=$(jq -er --arg current "$current_version" '
        .Versions |
        if type == "array" and length >= 1 and length <= 5 and
            all(.[]; (.VersionId | type == "string" and test("^v[1-9][0-9]*$")) and
                (.IsDefaultVersion | type == "boolean") and
                (.CreateDate | type == "string" and length > 0)) and
            ((map(.VersionId) | unique | length) == length) and
            ((map(select(.IsDefaultVersion)) | map(.VersionId)) == [$current])
        then length else error("Invalid or concurrently changed policy version history") end
    ' "$work_dir/versions.json")
    if (( version_count == 5 )); then
        oldest_version=$(jq -er --arg current "$current_version" '
            .Versions | map(select(.IsDefaultVersion == false and .VersionId != $current)) |
            sort_by(.CreateDate) | .[0].VersionId
        ' "$work_dir/versions.json")
        if ! aws iam delete-policy-version --policy-arn "$arn" --version-id "$oldest_version" \
            --output json >"$work_dir/deleted.json" 2>"$work_dir/aws-error"; then
            report_aws_error "Could not delete oldest non-default version $oldest_version of $name."
            return 1
        fi
        printf 'Deleted oldest non-default version %s: %s\n' "$oldest_version" "$arn"
    fi

    if ! aws iam create-policy-version --policy-arn "$arn" --policy-document "file://$name.json" \
        --set-as-default --output json >"$work_dir/updated.json" 2>"$work_dir/aws-error"; then
        report_aws_error "Could not create a new default version of $name; previous default was $current_version."
        return 1
    fi
    if ! jq -e '.PolicyVersion | .IsDefaultVersion == true and
        (.VersionId | type == "string" and test("^v[1-9][0-9]*$"))' "$work_dir/updated.json" >/dev/null; then
        printf 'ERROR: Invalid update response for policy %s; inspect its current default before retrying.\n' "$name" >&2
        return 1
    fi
    printf 'Updated default version: %s\n' "$arn"
}

for policy in "${policies[@]}"; do
    reconcile_policy "${policy%%|*}" "${policy#*|}"
done