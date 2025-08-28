# Copyright 2024 Esri
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

# The script adds tags and configures versioning for an S3 bucket that is required
# to support the backup and restore workflows that leverage the AWS Backup service.
# The script adds ArcGISSiteId, ArcGISDeploymentId, and ArcGISRole tags to the
# specified S3 bucket. If the tags already exist, they are updated with the new values.
# The script also enables versioning on the bucket if it is not already enabled.

import argparse
import boto3

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='tag_s3_bucket.py',
        description='Adds tags and configures versioning for an S3 bucket')

    parser.add_argument('-b', dest='bucket_name', help='S3 bucket name')
    parser.add_argument('-s', dest='site_id', help='Site Id')
    parser.add_argument('-d', dest='deployment_id', help='Deployment Id')
    parser.add_argument('-m', dest='role', help='S3 bucket role')

    args = parser.parse_args()

    print("Adding tags and configuring versioning for S3 bucket '{}'.".format(args.bucket_name))

    s3 = boto3.resource('s3')
    bucket = s3.Bucket(args.bucket_name)
    tags = {
        'ArcGISSiteId': args.site_id,
        'ArcGISDeploymentId': args.deployment_id,
        'ArcGISRole': args.role
    }

    # Add tags to the S3 bucket
    bucket.Tagging().put(Tagging={'TagSet': [{'Key': k, 'Value': v} for k, v in tags.items()]})
    print("Tags added to the S3 bucket.")

    # Enable versioning on the S3 bucket
    bucket.Versioning().enable()
    print("Versioning enabled for the S3 bucket.")