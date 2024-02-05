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

    print("Testing ListBucket, PutObject, and GetObject requests on S3 bucket '{0}'...".format(args.bucket_name))

    s3_client.list_objects_v2(
        Bucket=args.bucket_name,
        MaxKeys=1,
        Prefix='test'
    )

    print("ListBucket request succeeded.")
    
    s3_client.put_object(
        Bucket=args.bucket_name,
        Key='test.txt',
        Body=b'test'
    )

    print("PutObject request succeeded.")
    
    s3_client.get_object(   
        Bucket=args.bucket_name,
        Key='test.txt'
    )

    print("GetObject request succeeded.")      
