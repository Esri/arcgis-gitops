import os
import argparse
from typing import Sequence
from clients.enterprise_admin_client import EnterpriseAdminClient

def create_argument_parser(prog, description) -> argparse.ArgumentParser:    
    parser = argparse.ArgumentParser(prog="gis " + prog, description=description)

    parser.add_argument('--url', dest='url', required=False, help='ArcGIS Enterprise URL')
    parser.add_argument('-u', '--user', dest='user', required=False, help='ArcGIS Enterprise user name')
    parser.add_argument('-p', '--password', dest='password', required=False, help='ArcGIS Enterprise user password')

    return parser


def create_admin_client(args: Sequence[str]) -> EnterpriseAdminClient:
    user = args.user
    password = args.password

    if args.url:
        url = args.url
    elif 'ARCGIS_ENTERPRISE_URL' in os.environ:
        url = os.environ['ARCGIS_ENTERPRISE_URL']
    else:
        raise ValueError('ArcGIS Enterprise URL is not provided.')

    if args.user:
        user = args.user
    elif 'ARCGIS_ENTERPRISE_USER' in os.environ:
        user = os.environ['ARCGIS_ENTERPRISE_USER']
    else:
        raise ValueError('ArcGIS Enterprise user name is not provided.')
    
    if args.password:
        password = args.password
    elif 'ARCGIS_ENTERPRISE_PASSWORD' in os.environ:
        password = os.environ['ARCGIS_ENTERPRISE_PASSWORD']
    else:     
        raise ValueError('ArcGIS Enterprise user password is not provided.')
    
    return EnterpriseAdminClient(url, user, password)
