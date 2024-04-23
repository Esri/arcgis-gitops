import commands.cli_utils as cli_utils

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'register-s3-backup-store', 
        'Registers or updates S3 backup store.')

    parser.add_argument('--store', dest='store', required=True, help='backup store name')
    parser.add_argument('--bucket', dest='bucket', required=True, help='S3 bucket name')
    parser.add_argument('--region', dest='region', required=True, help='S3 bucket region')
    parser.add_argument('--root', dest='root', default='backups', help='S3 bucket root directory')
    parser.add_argument('--is-default', dest='is_default', action='store_true', help='make the store default')
    
    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)    
        
        stores = admin.get_disaster_recovery_stores()

        if args.store in [store['name'] for store in stores['backupStores']]:      
            admin.update_disaster_recovery_store(args.store, args.is_default)
            print("Backup store '{name}' updated.".format(name = args.store))
            exit(0)

        settings = {
            'type': 'S3',
            'provider': {
                'name': 'AWS',
                'cloudServices': [{
                    'name': 'AWS S3',
                    'type': 'objectStore',
                    'usage': 'BACKUP',
                    'connection': {
                        'bucketName': args.bucket,
                        'region': args.region,
                        'rootDir': args.root,
                        'credential': {
                            'type': 'IAM-ROLE'
                        },
                    },
                    'category': 'storage'
                }]
            }
        }

        ret = admin.register_disaster_recovery_store(args.store, settings, args.is_default)
       
        print("Backup store '{name}' registered.".format(name = args.store))
    except Exception as e:
        print(e)
        exit(1)
