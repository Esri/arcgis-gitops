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

import commands.cli_utils as cli_utils

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'generate-token', 
        'Generates an access token in exchange for user credentials.')
    
    parser.add_argument('--expiration', dest='expiration', type=int, default=60, help='The token expiration time in minutes')

    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)    
        
        token = admin.generate_token('referer', args.expiration)
        
        print(token)
    except Exception as e:
        print(e)
        exit(1)
