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
