import commands.cli_utils as cli_utils

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'update-dr-settings',
        'Updates the disaster recovery settings.')

    parser.add_argument('--storage-class', dest='storage_class', required=True, help='staging volume storage class')
    parser.add_argument('--size', dest='size', required=True, help='staging volume size (e.g. 64Gi)')
    parser.add_argument('--timeout', dest='timeout', type=int, required=False, help='backup job timeout (seconds)')
    
    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)

        ret = admin.update_disaster_recovery_settings(args.storage_class, args.size, args.timeout)
        
        print("Disaster recovery settings updated.")
    except Exception as e:
        print(e)
        exit(1)

