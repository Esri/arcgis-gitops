# Copyright 2024-2026 Esri
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

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }
}

data "aws_region" "current" {}

resource "null_resource" "s3_copy_files" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    environment = {
      AWS_DEFAULT_REGION = data.aws_region.current.region
    }

    command = "python -m s3_copy_files -f ${var.index_file} -b ${var.bucket_name}"
  }
}
