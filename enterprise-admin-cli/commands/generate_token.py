import commands.cli_utils as cli_utils

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'generate-token', 
        'Generates an access token in exchange for user credentials.')
    
    parser.add_argument('--expiration', dest='expiration', type=int, default=60, help='The token expiration time in minutes')

    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)    
        
        token = admin.generate_token('referer', args.expiration)
        
        print(token)
    except Exception as e:
        print(e)
        exit(1)
