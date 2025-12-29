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

# The script deletes IAM policies created by create-iam-policies.sh script.

delete_iam_policy() {
    local policy_arn="$1"

    if [[ -z "$policy_arn" ]]; then
        echo "Usage: delete_iam_policy <policy-arn>"
        return 1
    fi

    echo "Fetching policy versions for: $policy_arn"
    local versions
    versions=$(aws iam list-policy-versions \
        --policy-arn "$policy_arn" \
        --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
        --output text)

    for version in $versions; do
        echo "Deleting non-default version: $version"
        aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version"
    done

    echo "Deleting the policy itself..."
    aws iam delete-policy --policy-arn "$policy_arn"

    echo "Policy deleted: $policy_arn"
}

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseApplication
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseDestroy
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseImage
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseInfrastructure
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseK8s
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteCore
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteCoreDestroy
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteK8sCluster
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteK8sClusterDestroy
delete_iam_policy arn:aws:iam::$AWS_ACCOUNT_ID:policy/TerraformBackend