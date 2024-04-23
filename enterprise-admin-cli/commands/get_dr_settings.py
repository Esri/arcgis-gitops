import commands.cli_utils as cli_utils

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'get-dr-settings', 
        'Returns the currently configured disaster recovery settings.')

    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)    
        ret = admin.get_disaster_recovery_settings()
        if 'stagingVolumeConfig' in ret:
            staging_volume = ret['stagingVolumeConfig']  
            print("Staging volume configuration:") 
            print(" Storage Class: {storage_class}".format(storage_class = staging_volume['storageClass']))
            print(" Size: {size}".format(size = staging_volume['size']))
        else:
            print("Staging volume is not configured.")

    except Exception as e:
        print(e)
        exit(1)
