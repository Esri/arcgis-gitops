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

# Queries the Esri patch notification service for patches for a given set of products and versions.

import requests

class PatchNotification:
    
    def __init__(self, patches_url = 'https://downloads.esri.com/patch_notification/patches.json'):
        self.patches_url = patches_url

    # Returns a list of patches for the given products and versions
    # products: list of products to get patches for
    # versions: list of versions to get patches for
    def get_patches(self, products, versions):
        response = requests.get(self.patches_url)
        response.raise_for_status()

        all_patches = response.json()['Product']

        patches = []
        for version_patches in all_patches:
            if version_patches['version'] in versions:
                for patch in version_patches['patches']:
                    patch_products = patch['Products']
                    if not products or any(product in patch_products for product in products):
                        patches.append(patch)

        return patches
