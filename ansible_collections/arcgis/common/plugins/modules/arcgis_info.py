#!/usr/bin/python

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r'''
---
module: arcgis_info

short_description: Retrieves properteis from /home/<run_as_user>/.ESRI.properties.<hostname>.<ArcGIS version> file

version_added: "0.1.0"

description: The module parses /home/<run_as_user>/.ESRI.properties.<hostname>.<ArcGIS version> file and returns the properties as a dictionary.

options:
    arcgis_version:
        description: ArcGIS version
        required: true
        type: str
    hostname:
        description: Hostname of the machine
        required: true
        type: str
    run_as_user:
        description: ArcGIS account user name
        required: true
        type: str
'''

EXAMPLES = r'''
- name: Get properties of installed ArcGIS software version 11.2
  arcgis.common.arcgis_info:
      arcgis_version: 11.2
      hostname: 10.0.0.1
      run_as_user: arcgis
'''

RETURN = r'''
properties:
    description: Properties from /home/<run_as_user>/.ESRI.properties.<hostname>.<ArcGIS version> file
    type: dict
    returned: always
'''

import os

from ansible.module_utils.basic import AnsibleModule

# Function parses the specified file and returns the properties as a dictionary
def get_properties(file):
    properties = {}

    if not os.path.exists(file):
        return properties
    
    with open(file) as f:
        for line in f:
            if line.find('=') > 0:
                key, value = line.strip().split('=', 1)
                properties[key] = value
    
    return properties


def run_module():
    module_args = dict(
        hostname=dict(type='str', required=True),
        run_as_user=dict(type='str', required=True),
        arcgis_version=dict(type='str', required=True)
    )

    result = dict(
        changed=False,
        properties={}
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    properties_file = '/home/'+ module.params['run_as_user'] + '/.ESRI.properties.' + module.params['hostname'] + '.' + module.params['arcgis_version']
    
    properties = get_properties(properties_file)

    if module.check_mode:
        module.exit_json(**result)

    result['properties'] = properties

    # in the event of a successful module execution, you will want to
    # simple AnsibleModule.exit_json(), passing the key/value results
    module.exit_json(**result)


def main():
    run_module()


if __name__ == '__main__':
    main()