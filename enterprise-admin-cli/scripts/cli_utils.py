import os
import argparse
import requests
from time import sleep
from arcgis.gis import GIS
from typing import Sequence

WAIT_TIME = 60

def create_argument_parser(prog, description) -> argparse.ArgumentParser:    
    parser = argparse.ArgumentParser(prog="gis " + prog, description=description)

    parser.add_argument('--url', dest='url', required=False, help='ArcGIS Enterprise URL')
    parser.add_argument('-u', '--user', dest='user', required=False, help='ArcGIS Enterprise user name')
    parser.add_argument('-p', '--password', dest='password', required=False, help='ArcGIS Enterprise user password')

    return parser


def create_gis_client(args: Sequence[str]) -> GIS:
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
    
    wait_for_portal(url)

    return GIS(url=url, username=user, password=password)

def wait_for_portal(portal_url):
    portal_info_url = portal_url + '/sharing/rest/info?f=json'
    for i in range(WAIT_TIME):
        response = requests.get(portal_info_url)
        if response.status_code == 200:
            print('Portal URL is available.')
            break
        print('Portal URL is not available.')
        sleep(1.0)
