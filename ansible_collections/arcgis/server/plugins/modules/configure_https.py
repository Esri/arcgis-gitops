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
import time
__metaclass__ = type

DOCUMENTATION = r'''
---
module: configure_https

short_description: Configures SSL certificates of ArcGIS Server machine

version_added: "0.1.0"

description: This module configures SSL certificates of ArcGIS Server machine

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
    root_cert:
        description: Root certificate file path.
        required: false
        type: str
        default: ''
    root_cert_alias:
        description: Root certificate alias.
        required: false
        type: str
        default: ''
    keystore_file:
        description: Keystore file path.
        required: false
        type: str
        default: ''
    keystore_password
        description: Keystore password.
        required: false
        type: str
        default: ''
    cert_alias:
        description: Certificate alias.
        required: false
        type: str
        default: ''
'''

EXAMPLES = r'''
- name: Configure SSL certificates in ArcGIS Server machine
  arcgis.server.configure_https:
    server_url: https://localhost:6443/arcgis
    admin_username: siteadmin
    admin_password: <password>
    root_cert: /path/to/root_cert.pem
    root_cert_alias: root_cert
    keystore_file: /path/to/keystore.pfx
    keystore_password: <password>
    cert_alias: my_cert
'''

RETURN = r'''
changed:
    description: true if the resource was changed.
    type: bool
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
        root_cert=dict(type='str', required=False, default=''),
        root_cert_alias=dict(type='str', required=False, default=''),
        keystore_file=dict(type='str', required=False, default=''),
        keystore_password=dict(type='str', required=False, default=''),
        cert_alias=dict(type='str', required=False, default=''),
    )

    result = dict(
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

        machine_name = admin_client.get_local_machine_name()

        # Import root certificate if it does not exist
        if module.params['root_cert'] != '' and not admin_client.ssl_certificate_exists(machine_name,
            module.params['root_cert_alias'], 'trustedCertEntry'):
            admin_client.import_root_ssl_certificate(machine_name,
                                                     module.params['root_cert'],
                                                     module.params['root_cert_alias'])
            result['changed'] = True

        cert_alias = admin_client.get_server_ssl_certificate(machine_name)

        if module.params['keystore_file'] != '' and cert_alias != module.params['cert_alias']:
            if not admin_client.ssl_certificate_exists(machine_name, module.params['cert_alias']):
                admin_client.import_server_ssl_certificate(machine_name,
                                                           module.params['keystore_file'],
                                                           module.params['keystore_password'],
                                                           module.params['cert_alias'])

            admin_client.set_server_ssl_certificate(machine_name, module.params['cert_alias'])
            result['changed'] = True

            # Editing the machine configuration causes the machine to be restarted.
            admin_client.wait_until_available
            time.sleep(60)
            admin_client.wait_until_available
        
        module.exit_json(**result)        
    except Exception as e:
        module.fail_json(msg=str(e), **result)


def main():
    run_module()


if __name__ == '__main__':
    main()