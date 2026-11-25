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

# Replaces occurrences of a source SID with a target SID in a raw security descriptor.
#
# Parameters:
#   -SecurityDescriptor: The raw security descriptor to modify.
#   -SourceSid: The SID to replace.
#   -TargetSid: The SID to replace with.
#   -IncludeInherited: If specified, inherited ACEs are also updated.

function Convert-ArcGISSecurityDescriptorSid {
    param(
        [Parameter(Mandatory = $true)]
        [Security.AccessControl.RawSecurityDescriptor]$SecurityDescriptor,
        [Parameter(Mandatory = $true)]
        [Security.Principal.SecurityIdentifier]$SourceSid,
        [Parameter(Mandatory = $true)]
        [Security.Principal.SecurityIdentifier]$TargetSid,
        [switch]$IncludeInherited
    )

    $bytes = [byte[]]::new($SecurityDescriptor.BinaryLength)
    $SecurityDescriptor.GetBinaryForm($bytes, 0)
    $result = [Security.AccessControl.RawSecurityDescriptor]::new($bytes, 0)

    if ($result.Owner -eq $SourceSid) {
        $result.Owner = $TargetSid
    }

    if ($null -ne $result.DiscretionaryAcl) {
        foreach ($ace in $result.DiscretionaryAcl) {
            if ($ace -isnot [Security.AccessControl.KnownAce]) {
                throw "Unsupported discretionary ACE type '$($ace.AceType)'; no descriptor was written."
            }
            if (($IncludeInherited -or -not $ace.AceFlags.HasFlag([Security.AccessControl.AceFlags]::Inherited)) -and
                $ace.SecurityIdentifier -eq $SourceSid) {
                if ($ace -is [Security.AccessControl.QualifiedAce] -and $ace.IsCallback) {
                    throw 'A callback DACL entry references the old SID; use an approved migration.'
                }
                $ace.SecurityIdentifier = $TargetSid
            }
        }
    }

    return $result
}
