#!/usr/bin/env python

# Tests ArcGIS Enterprise deployment by publishing feature service from CSV file.

import argparse
import scripts.cli_utils as cli_utils
from arcgis.gis import GIS


if __name__ == '__main__':

    parser = argparse.ArgumentParser(prog="gis test-server-admin", description='Tests ArcGIS Server admin endpoint accessibility.')

    parser.add_argument('--url', dest='url', required=False, help='ArcGIS Server URL')
    parser.add_argument('-u', '--user', dest='user', required=False, help='ArcGIS Server administrator user name')
    parser.add_argument('-p', '--password', dest='password', required=False, help='ArcGIS Server administrator user password')
    
    args = parser.parse_args()

    try:
        server_admin_client = cli_utils.create_server_admin_client(args)

        properties = server_admin_client.properties

        if "fullVersion" not in properties:
            print("Failed to get server properties.")
            exit(1)

        print("ArcGIS Server version: {0}".format(server_admin_client.properties["fullVersion"]))

        machines = server_admin_client.machines
        
        for machine in machines.list():
            tokens = machine.url.split("/")
            status = machine.status
            hardware = machine.hardware
            print("Machine: {0}".format(tokens[-1]))
            print("  Configured state: {0}".format(status["configuredState"]))
            print("  Real time state: {0}".format(status["realTimeState"]))
            print("  CPU: {0}".format(hardware['cpu'].replace("\n", "; ")))
            print("  OS: {0}".format(hardware['os']))
            print("  Memory: {0}MB".format(hardware['systemMemoryMB']))
    except Exception as e:
       print(e)
       exit(1)
