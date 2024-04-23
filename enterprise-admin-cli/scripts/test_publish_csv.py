#!/usr/bin/env python

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
                      'tags': 'arcgis, python, csv',}

    print("Uploading CSV...")
    csv_item = gis.content.add(item_properties=csv_properties, data=csv_path)
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
