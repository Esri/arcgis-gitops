#!/usr/bin/python

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

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r'''
---
module: set_system_properties

short_description: Sets system properties of ArcGIS Server site

version_added: "0.1.0"

description: This module sets system properties of ArcGIS Server site

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
    system_properties:
        description: Dictionary of system properties to be set.
        required: false
        type: dict
        default: {}
    services_dir_enabled:
        description: Enable or disable services directory.
        required: false
        type: bool    
        default: true
'''

EXAMPLES = r'''
- name: Set ArcGIS Server system properties
  arcgis.server.set_system_properties:
    server_url: https://localhost:6443/arcgis
    admin_username: siteadmin
    admin_password: <password>
    system_properties:
        suspendedMachineUnregisterThreshold: -1
        machineSuspendThreshold: 60
    services_dir_enabled: false
'''

RETURN = r'''
response:
    description: server reaponse.
    type: str
    returned: always
'''

# import os
from ansible.module_utils.basic import AnsibleModule
from ansible_collections.arcgis.server.plugins.module_utils.server_admin_client import ServerAdminClient


def run_module():
    module_args = dict(
        server_url=dict(type='str', required=False, default='https://localhost:6443/arcgis'),
        admin_username=dict(type='str', required=True),
        admin_password=dict(type='str', required=True),
        system_properties=dict(type='dict', required=False, default={}),
        services_dir_enabled=dict(type='bool', required=False, default=True)
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
    
    try:
        admin_client.wait_until_available()

        result['response'] = admin_client.update_system_properties(module.params['system_properties'])
        
        admin_client.edit_services_directory_properties(module.params['services_dir_enabled'])

        result['changed'] = True

        module.exit_json(**result)        
    except Exception as e:
        module.fail_json(msg=str(e), **result)


def main():
    run_module()


if __name__ == '__main__':
    main()