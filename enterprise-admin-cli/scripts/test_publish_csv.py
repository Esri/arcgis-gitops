#!/usr/bin/env python

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

# Tests ArcGIS Enterprise deployment by publishing feature service from CSV file.

import os
import scripts.cli_utils as cli_utils
from time import sleep
from arcgis.gis import GIS


def publish_csv(gis):
    data_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "samples")

    # csv_path = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv'
    csv_path = os.path.join(data_path, "earthquakes.csv")
    # thumbnail_path = os.path.join(data_path, "earthquakes.png")

    csv_properties = {'title': 'Test CSV',
                      'description': 'CSV publishing test',
                      'type': 'CSV',
                      'tags': 'arcgis, python, csv',}

    print("Uploading CSV...")
    root_folder = gis.content.folders.get(folder="/")
    csv_item = root_folder.add(item_properties=csv_properties, file=csv_path).result()
    print("CSV uploaded. Item Id: {0}".format(csv_item.id))

    sleep(10.0)

    try:
        print("Publishing feature service from the uploaded CSV...")
        feature_service_item = csv_item.publish()
        print("Feature service published. Item Id: {0}".format(feature_service_item.id))

        print("Deleting the feature service...")
        feature_service_item.delete()
        print("Feature service deleted.")
    finally:
        print("Deleting the uploaded item...")
        csv_item.delete()
        print("Uploaded item deleted.")


if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'test-publish-csv',
        'Tests ArcGIS Enterprise deployment by publishing feature service from CSV file.')
    
    args = parser.parse_args()

    try:
        gis = cli_utils.create_gis_client(args)

        publish_csv(gis)
    except Exception as e:
        print(e)
        exit(1)
