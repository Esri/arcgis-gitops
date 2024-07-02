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
module: federate_server

short_description: Federates an ArcGIS Server with Portal for ArGIS.

version_added: "0.1.0"

description: This module federates an ArcGIS Server with Portal for ArGIS in a specific role and function.

options:
    portal_org_id:
        description: ArcGIS Enterprise organization Id.
        required: false
        type: str
    portal_url:
        description: URL of the Portal for ArcGIS.
        required: true
        type: str
    username:
        description: Portal for ArcGIS administrative account name.
        required: true
        type: str
    password:
        description: Portal for ArcGIS administrative account password.
        required: true
        type: str
    server_url:
        description: URL of the ArcGIS Server.
        required: false
        type: str 
    server_admin_url:
        description: URL of the ArcGIS Server administrative endpoint.
        required: true
        type: str
    server_username:
        description: ArcGIS Sever administrative account name.
        required: true
        type: str
    server_password:
        description: ArcGIS Server administrative account password.
        required: true
        type: str
    server_role:
        description: Indicates whether the server will be federated as a hosting server.
        required: false
        type: string
        default: FEDERATED_SERVER
    server_function:
        description: The function of the federated server.
        required: false
        type: str
        default: ''
'''

EXAMPLES = r'''
- name: Federate ArcGIS Server with Portal for ArcGIS as Raster Analytics server
  arcgis.portal.federate_server:
    portal_org_id: 0123456789ABCDEF
    portal_url: https://portal.domain.com:7443/arcgis
    username: portaladmin
    password: <portal password>
    server_url: https://server.domain.com/arcgis
    server_admin_url: https://server.domain.com:6443/arcgis
    server_username: serveradmin
    server_password: <server password>
    server_role: FEDERATED_SERVER
    server_function: RasterAnalytics
'''

RETURN = r'''
    server_id:
        description: The ID of the federated server.
        type: str
        returned: always
'''

import os
from ansible.module_utils.basic import AnsibleModule
from ansible_collections.arcgis.portal.plugins.module_utils.org_admin_client import OrgAdminClient


def run_module():
    module_args = dict(
        portal_url=dict(type='str', required=True),
        portal_org_id=dict(type='str', required=False, default=None),    
        username=dict(type='str', required=True),
        password=dict(type='str', required=True),
        server_url=dict(type='str', required=True),
        server_admin_url=dict(type='str', required=True),
        server_username=dict(type='str', required=True),
        server_password=dict(type='str', required=True),
        server_role=dict(type='str', required=False, default='FEDERATED_SERVER'),
        server_function=dict(type='str', required=False, default='')
    )

    result = dict(
        server_id='',
        changed=False
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    if module.check_mode:
        module.exit_json(**result)
    
    admin = OrgAdminClient(module.params['portal_url'], 
                              module.params['username'], 
                              module.params['password'],
                              module.params['portal_org_id'])
    
    try:
        # admin.wait_until_available()

        servers = admin.get_servers()['servers']
        
        server = next((s for s in servers if s['url'] == module.params['server_url']), None)

        if server is None:
            result['server_id'] = admin.federate_server(
                module.params['server_url'],
                module.params['server_admin_url'],
                module.params['server_username'],
                module.params['server_password']
            )['serverId']

            result['changed'] = True
        else:
            result['server_id'] = server['id']

        admin.update_server(
            result['server_id'],
            module.params['server_role'],
            module.params['server_function'])
        
        result['changed'] = True
        
        module.exit_json(**result)        
    except Exception as e:
        module.fail_json(msg=str(e), **result)


def main():
    run_module()


if __name__ == '__main__':
    main()