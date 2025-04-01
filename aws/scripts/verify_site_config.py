# Copyright 2025 Esri
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

# The script verifies the site configuration. In particular the script checks that:
# - The site index file exists and is valid JSON.
# - The site_id is set and the same in all the config files of the site.
# - The values of attributes are the same across all the deployment's config files.
# - The values of attributes are set and not placeholders (e.g., <value>).
# - The files referenced by properties specified by FILE_PATH_PROPERTIES array exist.

import json
import os
import argparse


# The properties that are skipped during the integrity check.
# These properties are not expected to be the same across all config files.
SKIP_PROPERTIES = [
    "root_volume_size",
    "instance_type"
]

# The properties that are checked for file existence.
# These properties are expected to point to existing files.
FILE_PATH_PROPERTIES = [
    "portal_authorization_file_path",
    "server_authorization_file_path",
    "keystore_file_path",
    "tls_certificate_path",
    "tls_private_key_path",
    "ca_certificate_path"
]

# Checks if a file exists at the given path.
# Replaces '~' with the user's home directory if present.
def file_exists(file_path):
    return os.path.isfile(file_path.replace('~', os.getenv('HOME')))


# Checks for missing values (placeholders) of required properties in the configuration files.
# Returns True if all required properties are set, False otherwise.
def check_placeholders(config_dir):
    ret = True

    for file_name in os.listdir(config_dir):
        if file_name.endswith('.json'):
            config_file = os.path.join(config_dir, file_name)
           
            with open(config_file, 'r') as cf:
                config = json.load(cf)

            for (key, value) in config.items():
                # Check if value starts and ends with <>
                # print(f"Checking {key} = {value}...")
                if isinstance(value, str) and value.startswith('<') and value.endswith('>'):
                    ret = False
                    print(f"ERROR(1): Missing value for \"{key}\" in {config_file}.")
                    continue
        
    return ret


# Returns true if files referenced by properties like "portal_authorization_file_path" and "server_authorization_file_path" exist.
# Returns false otherwise.
def check_file_existence(config_dir):
    ret = True

    for file_name in os.listdir(config_dir):
        if file_name.endswith('.json'):
            config_file = os.path.join(config_dir, file_name)
            
            with open(config_file, 'r') as cf:
                config = json.load(cf)

            for (key, value) in config.items():
                if key in FILE_PATH_PROPERTIES and isinstance(value, str) and not file_exists(value):
                    ret = False
                    print(f"ERROR(2): File \"{value}\" does not exist for \"{key}\" in {config_file}.")
    
    return ret


# Checks the integrity of the configuration files in the specified directory.
# Returns true if the values of attributes are the same across all the config files in a directory.
def check_integrity(config_dir):
    ret = True
    combined_config = {}
    
    for file_name in os.listdir(config_dir):
        with open(os.path.join(config_dir, file_name), 'r') as cf:
            config_properties = json.load(cf)
            for (key, value) in config_properties.items():
                if key in SKIP_PROPERTIES:
                    continue
                if key in combined_config:
                    if combined_config[key]['value'] != value:
                        ret = False
                        print(f"ERROR(3): Inconsistent value for \"{key}\" across files in {config_dir}. The value in {combined_config[key]['file_name']} is \"{combined_config[key]['value']}\", while the value in {file_name} is \"{value}\".")
                else:
                    combined_config[key] = {
                        'value': value,
                        'file_name': file_name
                    }
    
    return ret


# Check that site_id is set and the same in all the config files of the site.
# Returns true if site_id is set and the same in all the config files, false otherwise.
def check_site_id(site_index_path):
    ret = True

    with open(site_index_path, 'r') as si:
        site_index = json.load(si)

    infrastructure_core_json = os.path.join(site_index['core'], 'infrastructure-core.tfvars.json')
    
    with open(infrastructure_core_json, 'r') as icf:
        site_id = json.load(icf)['site_id']

    for config_dir in site_index['deployments']:
        for file_name in os.listdir(config_dir):
            if file_name.endswith('.json'):
                with open(os.path.join(config_dir, file_name), 'r') as cf:
                    config_properties = json.load(cf)
                    if 'site_id' not in config_properties:
                        ret = False
                        print(f"ERROR(4): Missing \"site_id\" in {os.path.join(config_dir, file_name)}.")
                    elif config_properties['site_id'] != site_id:
                        ret = False
                        print(f"ERROR(5): Invalid \"site_id\" in {os.path.join(config_dir, file_name)}. Expected \"{site_id}\", found \"{config_properties['site_id']}\".")
    
    return ret


# Verifies the site configuration by checking config files in directories 
# specified by the site index.
def verify_site_config(site_index_path):
    ret = True

    if not check_site_id(site_index_path):
        ret = False
    
    with open(site_index_path, 'r') as si:
        site_index = json.load(si)

    if not check_placeholders(site_index['core']):
        ret = False

    if not check_file_existence(site_index['core']):
        ret = False
    
    if not check_integrity(site_index['core']):
        ret = False
    
    for config_dir in site_index['deployments']:
        if not check_placeholders(config_dir):
            ret = False
        
        if not check_file_existence(config_dir):
            ret = False
        
        if not check_integrity(config_dir):
            ret = False
    
    return ret


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='verify_site_config.py',
        description='Verifies configuration of the site referenced by the specified index JSON file.')

    parser.add_argument('-i', dest='site_index', help='Site index file path')

    args = parser.parse_args()

    if not os.path.exists(args.site_index):
        print(f"Site index file does not exist: {args.site_index}")
        exit(1)

    if verify_site_config(args.site_index):
        print("Site configuration verification passed.")
    else:
        print("Site configuration verification failed.")
        exit(1)         
