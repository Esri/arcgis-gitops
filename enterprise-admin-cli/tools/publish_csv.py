#!/usr/bin/env python

# Tests the service endpoint by publishing a feature service

import os
import argparse
import requests
from time import sleep
from arcgis.gis import GIS

WAIT_TIME = 60

def wait_for_portal(portal_url):
    portal_info_url = portal_url + '/sharing/rest/info?f=json'
    for i in range(WAIT_TIME):
        response = requests.get(portal_info_url)
        if response.status_code == 200:
            print('Portal URL is available.')
            break
        print('Portal URL is not available.')
        sleep(1.0)

def publish_csv(portal_url, username, password):
    gis = GIS(url=portal_url, username=username, password=password)

    data_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "samples")

    # csv_path = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv'
    csv_path = os.path.join(data_path, "earthquakes.csv")
    thumbnail_path = os.path.join(data_path, "earthquakes.png")

    csv_to_delete = gis.content.search('title: Earthquakes past month')

    # Delete existing service if any
    for item in csv_to_delete:
        if item:
            print("Deleting {0} '{1}'...".format(item.type, item.title))
            item.delete()

    csv_properties = {'title': 'Earthquakes past month',
                      'description': 'Measurements from globally distributed seismometers',
                      'tags': 'arcgis, python, earthquake, natural disaster, emergency'}

    print("Uploading CSV...")
    csv_item = gis.content.add(
        item_properties=csv_properties, data=csv_path, thumbnail=thumbnail_path)
    print("CSV uploaded. Item Id: {0}".format(csv_item.id))

    sleep(60.0)

    print("Publishing feature service from the uploaded CSV...")
    feature_service_item = earthquake_feature_layer_item = csv_item.publish()
    print("Feature service published. Item Id: {0}".format(feature_service_item.id))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='publish_csv.py',
        description='Tests base ArcGIS Enterprise deployment by publishing a feature service.')

    parser.add_argument('-a', dest='url', required=True, help='Portal for ArcGIS URL')
    parser.add_argument('-u', dest='username', required=True, help='Portal for ArcGIS user name')
    parser.add_argument('-p', dest='password', required=True, help='Portal for ArcGIS user password')

    args = parser.parse_args()

    wait_for_portal(args.url)
    publish_csv(args.url, args.username, args.password)
