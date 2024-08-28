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

DOCUMENTATION = r'''
---
module: s3files

short_description: Downloads files from S3 bucket to local directories

version_added: "0.1.0"

description: Downloads software setups and patches specified in the manifest file from S3 bucket to local software repository directories.

requirements:
    - AWS.Tools.S3 PowerShell module installed
    - AWS credentials configured on the host

options:
    manifest:
        description: Path to the manifest file that contains the list of files to download from S3 bucket.
        required: true
        type: str
'''

EXAMPLES = r'''
- name: Download setups from private S3 repository
  arcgis.windows.s3files:
    manifest: 'C:\\Software\\arcgis-server-s3files-11.2.json'
'''

RETURN = r'''
output:
    description: The output messages that the module generates.
    type: list
    returned: always
    elements: str
'''

