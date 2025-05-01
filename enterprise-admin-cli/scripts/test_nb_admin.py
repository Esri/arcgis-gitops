#!/usr/bin/env python

# Copyright 2025 Esri
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

# Tests ArcGIS Notebook Server admin endpoint accessibility.

import argparse
import scripts.cli_utils as cli_utils
from arcgis.gis import GIS
from arcgis.gis.nb import NotebookServer


if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'test-nb-admin',
        'Tests ArcGIS Notebook Server admin endpoint accessibility.')
    parser.add_argument('--nb-url', dest='nb_url', required=False, help='ArcGIS Notebook Server URL')
    
    args = parser.parse_args()

    try:
        gis = cli_utils.create_gis_client(args)
        
        nb_admin_client = NotebookServer(args.nb_url, gis)

        properties = nb_admin_client.info

        if "fullVersion" not in properties:
            print("Failed to get server properties.")
            exit(1)

        print("ArcGIS Notebook Server version: {0}".format(properties["fullVersion"]))
    except Exception as e:
       print(e)
       exit(1)
