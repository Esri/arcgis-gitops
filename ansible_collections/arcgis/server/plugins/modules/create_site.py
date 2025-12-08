#!/usr/bin/python

# Copyright 2024-2025 Esri
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

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r'''
---
module: create_site

short_description: Creates a new ArcGIS Server site or upgrades an existing site if required.

version_added: "0.1.0"

description: This module creates a new ArcGIS Server site or upgrades an existing site if required.

options:
    server_url:
        description: URL of the ArcGIS Server instance.
        required: false
        type: str 
        default: 'https://localhost:6443/arcgis'
    admin_username:
        description: Name of the administrative account to be used by the site.
        required: true
        type: str
    admin_password:
        description: Password of the administrative account.
        required: true
        type: str
    directories_root:
        description: Root directory for server directories.
        required: true
        type: str
    config_store_type:
        description: Type of the configuration store.
        required: false
        type: str
        default: FILESYSTEM
    config_store_connection_string:
        description: Connection properties for the configuration store.
        required: false
        type: str
        default: None
    config_store_connection_secret:
        description: Secret for the configuration store connection.
        required: false
        type: str
        default: ''
    cloud_config:
        description: Cloud configuration for object storage.
        required: false
        type: str
        default: None
    log_level:
        description: Log level for the site.
        required: false
        type: str
        default: WARNING
    log_dir:
        description: Directory for log files.
        required: false
        type: str
        default: None
    max_log_file_age:
        description: Maximum age of log files.
        required: false
        type: int
        default: 90
'''

EXAMPLES = r'''
- name: Create ArcGIS Server site
  arcgis.server.create_site:
    server_url: https://localhost:6443/arcgis
    admin_username: siteadmin
    admin_password: <password>
    server_directories_root: /gisdata/arcgisserver
    config_store_type: FILESYSTEM
    config_store_connection_string: /gisdata/arcgisserver/config-store
    config_store_connection_secret: ''
    log_level: WARNING
    log_dir: /opt/arcgis/server/usr/logs
    max_log_file_age: 90
'''

RETURN = r'''
response:
    description: server response.
    type: str
    returned: always
'''

import os
from ansible.module_utils.basic import AnsibleModule
from ansible_collections.arcgis.server.plugins.module_utils.server_admin_client import ServerAdminClient


def run_module():
    module_args = dict(
        server_url=dict(type='str', required=False, default='https://localhost:6443/arcgis'),
        admin_username=dict(type='str', required=True),
        admin_password=dict(type='str', required=True),
        directories_root=dict(type='str', required=True),
        config_store_type=dict(type='str', required=False, default='FILESYSTEM'),
        config_store_connection_string=dict(type='str', required=False, default=None),
        config_store_connection_secret=dict(type='str', required=False, default=''),
        cloud_config=dict(type='str', required=False, default=None),
        log_level=dict(type='str', required=False, default='WARNING'),
        log_dir=dict(type='str', required=False, default=None),
        max_log_file_age=dict(type='int', required=False, default=90)
    )

    result = dict(
        response='',
        changed=False
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    if module.check_mode:
        module.exit_json(**result)
    
    admin_client = ServerAdminClient(module.params['server_url'], 
                                     module.params['admin_username'], 
                                     module.params['admin_password'])
    
    config_store_connection = None
    cloud_config = None
    directories = None

    if module.params['cloud_config']:
        # Store server directories configured with ArcGIS Server in 
        # object storage from a cloud service. 
        cloud_config = module.params['cloud_config']
    else:
        if module.params['config_store_connection_string'] is not None:
            config_store_connection = {
                'type' : module.params['config_store_type'],
                'connectionString' : module.params['config_store_connection_string'],
                'connectionSecret' : module.params['config_store_connection_secret']
            }
    
        if module.params['directories_root'] is not None:
            directories = { 
                'directories' : [{
                    'name' : 'arcgiscache',
                    'physicalPath' : os.path.join(module.params['directories_root'], 'directories', 'arcgiscache'),
                    'directoryType' : 'CACHE',
                    'cleanupMode' : 'NONE',
                    'maxFileAge' : 0,
                    'description' : 'Stores tile caches used by map, globe, and image services for rapid performance.'
                }, {
                    'name' : 'arcgisjobs',
                    'physicalPath' : os.path.join(module.params['directories_root'], 'directories', 'arcgisjobs'),
                    'directoryType' : 'JOBS',
                    'cleanupMode' : 'TIME_ELAPSED_SINCE_LAST_MODIFIED',
                    'maxFileAge' : 360,
                    'description' : 'Stores results and other information from geoprocessing services.'
                }, {
                    'name' : 'arcgisoutput',
                    'physicalPath' : os.path.join(module.params['directories_root'], 'directories', 'arcgisoutput'),
                    'directoryType' : 'OUTPUT',
                    'cleanupMode' : 'TIME_ELAPSED_SINCE_LAST_MODIFIED',
                    'maxFileAge' : 10,
                    'description' : 'Stores various information generated by services, such as map images.'
                }, {
                    'name' : 'arcgissystem',
                    'physicalPath' : os.path.join(module.params['directories_root'], 'directories', 'arcgissystem'),
                    'directoryType' : 'SYSTEM',
                    'cleanupMode' : 'NONE',
                    'maxFileAge' : 0,
                    'description' : 'Stores directories and files used internally by ArcGIS Server.'
                }] 
            }

    log_settings = {
        'logLevel' : module.params['log_level'],
        'maxErrorReportsCount' : 10,
        'maxLogFileAge' : module.params['max_log_file_age']
    }

    if module.params['log_dir'] is not None:
        log_settings['logDir'] = module.params['log_dir']

    try:
        admin_client.wait_until_available()

        if admin_client.upgrade_required():
            response = admin_client.complete_upgrade()
            result['response'] = response
            result['changed'] = True
        elif not admin_client.site_exists():
            response = admin_client.create_site(config_store_connection, directories,  cloud_config, log_settings, False)
            result['response'] = response
            result['changed'] = True
        
        module.exit_json(**result)        
    except Exception as e:
        module.fail_json(msg=str(e), **result)


def main():
    run_module()


if __name__ == '__main__':
    main()