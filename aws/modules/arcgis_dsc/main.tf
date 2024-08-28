/**
 * # Terraform module arcgis_dsc
 * 
 * Terraform module runs runs ArcGIS.Invoke-ArcGISConfiguration cmdlet with specified
 * configuration parameters on the deployment's EC2 instances in specified roles.
 * 
 * The module uses arcgis.windows.invoke_arcgis_configuration Ansible playbook with 
 * community.aws.aws_ssm connection plugin to connect to EC2 instances via AWS Systems Manager.
 *
 * ## Requirements
 *
 * The name of the S3 bucket used by the SSM connection for file transfers is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Ansible must be installed
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
 */

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

resource "local_sensitive_file" "configuration_parameters_file" {
  content  = var.json_attributes
  filename = "/tmp/${timestamp()}/configuration_parameters.json"
}

module "invoke_arcgis_configuration" {
  source        = "../ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = var.machine_roles
  playbook      = "arcgis.windows.invoke_arcgis_configuration"
  external_vars = {
    ansible_shell_type            = "powershell"
    configuration_parameters_file = local_sensitive_file.configuration_parameters_file.filename
    install_mode                  = var.install_mode
    execution_timeout             = var.execution_timeout
  }
  depends_on = [
    local_sensitive_file.configuration_parameters_file  
  ]
}
