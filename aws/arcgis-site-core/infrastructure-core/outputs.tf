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

output "vpc_id" {
  description = "VPC Id of ArcGIS Enterprise site"
  value       = aws_vpc.vpc.id
}

output "public_subnets" {
  description = "Public subnets"
  value       = aws_subnet.public_subnets.*.id
}

output "private_subnets" {
  description = "Private subnets"
  value       = aws_subnet.private_subnets.*.id
}

output "internal_subnets" {
  description = "Internal subnets"
  value       = aws_subnet.internal_subnets.*.id
}

