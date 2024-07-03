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

import os
import argparse
import requests
import arcgis
from time import sleep
from arcgis import *
from arcgis.gis import GIS
from arcgis.gis import server
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

def create_server_admin_client(args: Sequence[str]) -> server.Server:
    if args.url:
        url = args.url
    elif 'ARCGIS_SERVER_URL' in os.environ:
        url = os.environ['ARCGIS_SERVER_URL']
    else:
        raise ValueError('ArcGIS Server URL is not provided.')

    if args.user:
        user = args.user
    elif 'ARCGIS_SERVER_USER' in os.environ:
        user = os.environ['ARCGIS_SERVER_USER']
    else:
        raise ValueError('ArcGIS Server user name is not provided.')
    
    if args.password:
        password = args.password
    elif 'ARCGIS_SERVER_PASSWORD' in os.environ:
        password = os.environ['ARCGIS_SERVER_PASSWORD']
    else:     
        raise ValueError('ArcGIS Server user password is not provided.')

    return server.Server(url + "/admin", username=user, password=password, initialize=True)