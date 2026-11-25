# Copyright 2026 Esri
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

param([Parameter(Mandatory)][string]$EncodedPrivateDns)

$privateDns = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedPrivateDns))
$registryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'
if (-not (Test-Path -LiteralPath $registryPath)) {
    New-Item $registryPath -Force | Out-Null
}
New-ItemProperty -LiteralPath $registryPath -Name BackConnectionHostNames `
    -Value @($env:COMPUTERNAME, $privateDns, 'localhost', '127.0.0.1') `
    -PropertyType MultiString -Force | Out-Null
Write-Output 'Configured file-server BackConnectionHostNames.'
