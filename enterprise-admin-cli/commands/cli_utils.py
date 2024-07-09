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
from typing import Sequence
from clients.enterprise_admin_client import EnterpriseAdminClient

def create_argument_parser(prog, description) -> argparse.ArgumentParser:    
    parser = argparse.ArgumentParser(prog="gis " + prog, description=description)

    parser.add_argument('--url', dest='url', required=False, help='ArcGIS Enterprise URL')
    parser.add_argument('-u', '--user', dest='user', required=False, help='ArcGIS Enterprise user name')
    parser.add_argument('-p', '--password', dest='password', required=False, help='ArcGIS Enterprise user password')
    parser.add_argument('--password-file', dest='password_file', required=False, help='ArcGIS Enterprise user password file path')

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
    
    if args.password_file:
        with open(args.password_file, 'r') as file:
            password = file.read()
    elif 'ARCGIS_ENTERPRISE_PASSWORD_FILE' in os.environ:
        with open(os.environ['ARCGIS_ENTERPRISE_PASSWORD_FILE'], 'r') as file:
            password = file.read()

    if args.password:
        password = args.password
    elif 'ARCGIS_ENTERPRISE_PASSWORD' in os.environ:
        password = os.environ['ARCGIS_ENTERPRISE_PASSWORD']
    
    if not password:
        raise ValueError('ArcGIS Enterprise user password is not specified.')
    
    return EnterpriseAdminClient(url, user, password)
