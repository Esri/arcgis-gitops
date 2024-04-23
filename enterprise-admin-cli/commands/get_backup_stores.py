import commands.cli_utils as cli_utils

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'get-backup-stores', 
        'Returns backup stores registered with the deployment.')

    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)    
        
        ret = admin.get_disaster_recovery_stores()

        if 'backupStores' not in ret or len(ret['backupStores']) == 0:
            print("No backup stores are registered with the deployment.")
        else:
            for store in ret['backupStores']:
                print("Backup Store '{name}':".format(name = store['name'])) 
                print("  Type: {type}".format(type = store['type']))     
                print("  Default: {default}".format(default = store['default']))  
                print("  Version Created: {version}".format(version = store['versionCreated']))
                print("  Provider ID: {provider}".format(provider = store['providerID']))
                print("  Service ID: {service}".format(service = store['serviceID']))
                if store['type'] == 'S3':     
                    print("  Bucket Name: {bucket}".format(bucket = store['bucketName']))
                    print("  Region: {region}".format(region = store['region']))
    except Exception as e:
        print(e)
        exit(1)
