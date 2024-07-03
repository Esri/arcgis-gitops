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
module: join_site

short_description: Joins an existing ArcGIS Server site

version_added: "0.1.0"

description: This module joins the machine to an existing ArcGIS Server site.

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
    primary_server_url:
        description: URL of one of the server machines of the site.
        required: true
        type: str
'''

EXAMPLES = r'''
- name: Join ArcGIS Server site
  arcgis.server.join_site:
    server_url: https://localhost:6443/arcgis
    admin_username: siteadmin
    admin_password: <password>
    primary_server_url: https://primaryserver.domain.com:6443/arcgis
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
        primary_server_url=dict(type='str', required=True)
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

        if admin_client.upgrade_required():
            response = admin_client.complete_upgrade()
            result['response'] = response
            result['changed'] = True
        elif not admin_client.site_exists():
            response = admin_client.join_site(module.params['primary_server_url'] + '/admin', False)
            result['response'] = response
            result['changed'] = True
        
        module.exit_json(**result)        
    except Exception as e:
        module.fail_json(msg=str(e), **result)


def main():
    run_module()


if __name__ == '__main__':
    main()