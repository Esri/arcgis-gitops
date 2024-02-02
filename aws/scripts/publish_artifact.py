# Retrieves AMI Id from packer-manifest.json file and saves in SSM parameter.

import argparse
import json
import boto3

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='publish_artifact.py',
        description='Retrieves AMI Id from packer-manifest.json file and saves in SSM parameter.')

    parser.add_argument('-p', dest='parameter', help='SSM parameter name')
    parser.add_argument('-f', dest='manifest', help='packer-manifest.json file path')
    parser.add_argument('-r', dest='packer_run_uuid', help='Packer run UUID')

    args = parser.parse_args()

    with open(args.manifest, encoding="utf-8") as fp:
        manifest = json.load(fp)

    ami_id = None
    
    for build in manifest['builds']:
        if build['packer_run_uuid'] == args.packer_run_uuid:
            ami_id = build['artifact_id'].split(':')[1]
            ami_description = build['custom_data']['ami_description']
    
    if ami_id is None:
        print("The packer run UUID not found in {0} manifest file.".format(args.manifest))
        exit(1)

    ssm_client = boto3.client('ssm')

    ssm_client.put_parameter(
        Name=args.parameter,
        Description=ami_description,
        Value=ami_id,
        Type='String',
        Overwrite=True,
        Tier='Intelligent-Tiering'
    )

    print("AMI Id '{0}' stored in '{1}' SSM parameter.".format(ami_id, args.parameter))