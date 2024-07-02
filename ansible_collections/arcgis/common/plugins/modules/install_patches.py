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
module: install_patches

short_description: Installs ArcGIS patches

version_added: "0.1.0"

description: The module installs hot fixes and patches for ArcGIS software.

options:
    patch:
        description: Patch file name or pattern
        required: true
        type: str
    dir:
        description: Directory where patch files are stored
        required: true
        type: str
    log:
        description: Patchs log file path
        required: true
        type: str
    product:
        description: Product name
        required: false
        type: str    
'''

EXAMPLES = r'''
- name: Install ArcGIS Server 11.3 patches
  arcgis.common.install_patches:
    patch: 'ArcGIS-113-S-*.tar.gz'
    dir: '/opt/software/archives/patches'
    log: '/opt/arcgis/server/.ESRI_S_PATCH_LOG'
    product: 'server'
'''

RETURN = r'''
output:
    description: The output messages that the module generates.
    type: str
    returned: always
'''

import glob
import os
import tarfile
import tempfile
import subprocess

from ansible.module_utils.basic import AnsibleModule

def patch_installed(qfe_file, log):
    if not os.path.exists(log):
        return False
    
    with open(log) as f:
        for line in f:
            if line.find(qfe_file) > 0:
                return True

    return False

def run_module():
    module_args = dict(
        patch=dict(type='str', required=True),
        dir=dict(type='str', required=True),
        log=dict(type='str', required=True),
        product=dict(type='str', required=False, default=None)
    )

    result = dict(
        changed=False,
        output=[]
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    if module.check_mode:
        module.exit_json(**result)

    patch_file = os.path.join(module.params['dir'], module.params['patch'])

    for patch in glob.glob(patch_file):
        qfe_file = os.path.basename(patch)
        if patch_installed(qfe_file, module.params['log']):
            result['output'].append("Patch '{0}' is already installed".format(qfe_file)) 
        else:
            # Install the patch
            with tempfile.TemporaryDirectory() as tmpdir:
                with tarfile.open(patch) as tar:
                    tar.extractall(tmpdir)
                
                # Run 'applypatch' script if it exists.
                for applypatch in glob.glob("{0}/*/applypatch".format(tmpdir)):
                    args = "-s"
                    if module.params['product'] is not None:
                        args += " -{0}".format(module.params['product'])    

                    try:
                        subprocess.check_output("{0} {1}".format(applypatch, args), shell=True)
                        result['output'].append("Patch '{0}' installed successfully".format(qfe_file))
                        result['changed'] = True
                    except subprocess.CalledProcessError as ex:                                                                                                   
                        if ex.output.find("This patch is already installed.") > 0:
                            result['output'].append("Patch '{0}' is already installed".format(qfe_file))
                        else:
                            module.fail_json(msg=ex.output, **result)

                # Run 'Patch.sh' script if it exists.
                for patch_sh in glob.glob("{0}/*/Patch.sh".format(tmpdir)):
                    try:
                        subprocess.check_output(patch_sh, shell=True)
                        result['output'].append("Patch '{0}' installed successfully".format(qfe_file))
                        result['changed'] = True
                    except subprocess.CalledProcessError as ex:                                                                                                   
                        if ex.output.find("this product is already installed.'") > 0:
                            result['output'].append("Patch '{0}' is already installed".format(qfe_file))
                        else:
                            module.fail_json(msg=ex.output, **result)

    module.exit_json(**result)


def main():
    run_module()


if __name__ == '__main__':
    main()