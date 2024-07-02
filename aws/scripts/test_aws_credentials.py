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

# Tests the AWS credentials configured in the system by accessing the specified S3 bucket.

import argparse
import boto3


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='test_aws_credentials.py',
        description='Tests the AWS credentials configured in the system by accessing the specified S3 bucket.')

    parser.add_argument('-b', dest='bucket_name', required=True, help='S3 bucket name')

    args = parser.parse_args()

    session = boto3.session.Session()
   
    print("Default AWS region: {0}".format(session.region_name))

    s3_client = boto3.client('s3')

    print("Testing ListObjectsV2, PutObject, and GetObject requests on S3 bucket '{0}'...".format(args.bucket_name))

    try:
        s3_client.list_objects_v2(
            Bucket=args.bucket_name,
            MaxKeys=1,
            Prefix='test'
        )

        print("ListBucket test succeeded.")
        
        s3_client.put_object(
            Bucket=args.bucket_name,
            Key='test.txt',
            Body=b'test'
        )

        print("PutObject test succeeded.")
        
        s3_client.get_object(   
            Bucket=args.bucket_name,
            Key='test.txt'
        )

        print("GetObject test succeeded.")      
    except Exception as e:
        print(e)
        exit(1)

    print("The test passed.")      
