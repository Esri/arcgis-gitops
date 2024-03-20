# Helm Charts for ArcGIS Enterprise on Kubernetes

## Introduction

Welcome to the Helm Charts for ArcGIS Enterprise on Kubernetes readme! Helm Charts can be used to deploy, configure, update and upgrade ArcGIS Enterprise on Kubernetes.

## Why use Helm?

Helm is a user-friendly package manager for Kubernetes. For ArcGIS Enterprise on Kubernetes, Helm is an additional tool to help manage complexity, provide repeatability, and allow for a seamless experience across supported Kubernetes providers.

## System Requirements

The minimum hardware and infrastructure required to run ArcGIS Enterprise on Kubernetes are described in the ArcGIS Enterprise on Kubernetes [system requirements](https://enterprise-k8s.arcgis.com/en/latest/deploy/system-requirements.htm) documentation. For Helm, additional requirements are listed below:

* Helm CLI client v3.0.0 or later
   * The Helm CLI client can reside directly on the Kubernetes cluster or on a remote client workstation that contains a locally configured copy of kubectl.

* [TLS Certificate](https://enterprise-k8s.arcgis.com/en/latest/deploy/system-requirements.htm#ESRI_SECTION1_929E0E9C94304C89ABEB8CA86DC651BE)
   * At this release, only a self-signed certificate or an existing TLS secret that contains a private key and certificate are supported when deployed with Helm.

## Chart Version Compatibility
The following table explains the compatibility of chart versions and ArcGIS Enterprise on Kubernetes.

Helm Chart Version | ArcGIS Enterprise version | Initial deployment using `helm install` command | Release upgrade using `helm upgrade` command | Patch update using `helm upgrade` command | Description |
--- | --- | --- | --- | --- | --- |
v1.0.1 | 11.0.0.2632 | Supported     | Not supported  | Not applicable | Helm chart for deploying 11.0 |
v1.1.0 | 11.1.0.3923 | Supported     | Supported      | Not applicable | Helm chart for deploying 11.1 or upgrading 11.0 to 11.1 |
v1.1.1 | 11.1.0.4100 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.1 Help Language Pack Update |
v1.1.2 | 11.1.0.4105 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.1 Q3 2023 Security Update |
v1.1.3 | 11.1.0.4110 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.1 Q3 2023 Base Operating System Image Update |
v1.1.4 | 11.1.0.4115 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.1 Q4 2023 Bug Fix Update |
v1.2.0 | 11.2.0.5207 | Supported     | Supported      | Not applicable | Helm chart for deploying 11.2 or upgrading 11.1 to 11.2 |
v1.2.1 | 11.2.0.5500 | Not supported | Not applicable | Supported      | Helm chart to apply the 11.2 Help Language Pack Update |

## Deploy and Configure ArcGIS Enterprise on Kubernetes

### Modify values.yaml and configure.yaml

Once you have obtained the chart archive (.tgz), open a terminal as an administrator or super user on your Kubernetes client machine. Extract the file and change directories to the helm chart arcgis-enterprise folder. Inside this folder there will be a values.yaml file and a configure.yaml file.

The values.yaml and configure.yaml files contain the following sections that you will need to edit:

* Container Image Registry Details
* Install and Configure Inputs

Each of these sections contain values that you will need to customize for your unique deployment. Once you have made the appropriate changes, save both files.

### Chart Values for values.yaml

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.registry` | The fully qualified domain name (FQDN) of the container registry host (for example, docker.io). |  |
| `image.username` | The username for an account in the specified container registry that stores permissions to pull from the registry. |  |
| `image.password` | The password for the specified container registry account. |  |
| `image.repository` | Container repository for images to be pulled. |  |
| `image.tag` | Tag for the images the container registry pulls. |  |
| `install.enterpriseFQDN` | The FQDN needed to access ArcGIS Enterprise on Kubernetes. This points to a load balancer, reverse proxy, edge router, or other web front-end point configured to route traffic to the ingress controller. |  |
| `install.context` | Context path to be used in the URL for your Enterprise FQDN. | `arcgis` |
| `install.allowedPrivilegedContainers` | Allows privileged containers to run. Set allowedPrivilegedContainers to false if you cannot run a privileged container. When set to false, you need to set vm.max_map_count to 262144 on each node. | `true` |
| `install.configureWaitTimeMin` | When configure.enabled=true, an additional validation check is performed on the enterprise admin url to ensure it is accessible prior to configuring an organization. In some cloud environments it may take several minutes before the ingress controller is recognized, so adjust this value in minutes, as needed. | `15` |
| `install.ingress.ingressType` | The ingress controller exposes external traffic over service type LoadBalancer or NodePort. | `NodePort` |
| `install.ingress.loadBalancerType` | If the ingress type is LoadBalancer, define the load balancer type. Otherwise, leave blank. |  |
| `install.ingress.loadBalancerIP` | Use a preconfigured static public IP address for your load balancer. |  |
| `install.ingress.nodePortHttps` | Specify NodePort in the range 30,000–32,767 or leave blank. If a port is not specified, Kubernetes automatically allocates an available port in this range. |  |
| `install.ingress.ingressServiceUseClusterIP` | Specify whether a cluster-level ingress controller or OpenShift Route is being used for incoming traffic. | `false`|
| `install.ingress.tls.secretName` | Define your precreated TLS secret to use with the ingress controller. The `install.ingress.tls.secretName` and `install.ingress.tls.selfSignCN` are mutually exclusive so you can only define one option at a time. |  |
| `install.ingress.tls.selfSignCN` | Define a self-signed certificate common name. The `install.ingress.tls.secretName` and `install.ingress.tls.selfSignCN` are mutually exclusive so you can only define one option at a time. |  |
| `install.ingress.hstsEnabled` | Use HTTP Strict Transport Security. | `false`|
| `install.ingress.sslProtocols` | Define the TLS protocol supported. | `"TLSv1.2 TLSv1.3"`|
| `install.ingress.sslCiphers` | The Supported Cipher Suites. | `See description in values.yaml`|
| `install.k8sClusterDomain` | If your Kubernetes cluster has a domain name other than cluster.local, use this property to specify the domain name. | `cluster.local`|
| `common.verbose` | Allow commands that run inside the pre-install-hook-job pod to be run with a verbose setting. | `false`|
| `configure.enabled` | Configure an ArcGIS Enterprise organization after ArcGIS Enterprise on Kubernetes finishes deploying to the Kubernetes cluster. | `true` |
| `upgrade.token` | An ArcGIS token generated through the https://enterpriseFQDN/context/sharing/rest/generateToken endpoint. This token is used for upgrades and it needs to be a long lived token of at least 6 hours or more and created using an ArcGIS Enterprise organization administrator account.|  |
| `upgrade.mandatoryUpdateTargetId` | Used when upgrading to a new version of the software. Provide the patch ID of the required update. | |
| `upgrade.targetId` | Upgrade version target ID. This can refer to a release ID or an update patch ID. Do not change this. Download and run different helm charts for different target IDs. | `pat_06022024_5500` |
| `upgrade.licenseFile` | Your license file in the user-inputs folder, that will be used when upgrading ArcGIS Enterprise. |  |

### Chart Values for configure.yaml

| Parameter | Description | Default |
|-----------|-------------|---------|
| `configure.systemArchProfile` | Choose the predefined deployment profile that correlates to the levels of redundancy across your pods. There are three profiles to choose from: development, standard-availability, or enhanced-availability. The profile you choose will determine which pods are automatically replicated during setup. For more information about deployment types, see [Architecture profiles.](https://enterprise-k8s.arcgis.com/en/latest/deploy/architecture-profiles.htm) | `development` |
| `configure.licenseFile` | Your license file in the user-inputs folder, that will be used to configure an ArcGIS Enterprise organization. |  |
| `configure.licenseTypeId` | The user type ID for the primary administrator account. |  |
| `configure.admin.username` | The ArcGIS Enterprise on Kubernetes organization administrator account username. |  |
| `configure.admin.password` | The ArcGIS Enterprise on Kubernetes organization administrator account password. |  |
| `configure.admin.email` | The ArcGIS Enterprise on Kubernetes organization administrator account email. |  |
| `configure.admin.firstName` | The ArcGIS Enterprise on Kubernetes organization administrator first name. |  |
| `configure.admin.lastName` | The ArcGIS Enterprise on Kubernetes organization administrator last name. |  |
| `configure.securityQuestionIndex` | A numeric value between 1 and 14. See the `configure.yaml` file for full descriptions. |  |
| `configure.securityQuestionAnswer` | The answer to the secrity question. |  |
| `configure.cloudConfigJsonFilename` | The filename in user-inputs containing the optional cloud object store configuration. |  |
| `configure.logSetting` | The log level at which logs will be recorded during configuration. |  |
| `configure.logRetentionMaxDays` | The number of days logs will be retained by the system. | 60  |
| `configure.storage.*` | Storage properties for the data stores. See the `configure.yaml` file for full descriptions. |  |

### Install Chart

Once values.yaml and configure.yaml have been modified, you're ready to use `helm install` to deploy the chart by running the following command:

```
helm install arcgis --namespace <your namespace> -f <full path>/arcgis-enterprise/configure.yaml <full path>/arcgis-enterprise --timeout 60m0s --debug
```

The above command will deploy and configure ArcGIS Enterprise on Kubernetes using the values that are defined in values.yaml and configure.yaml. Replace `<your namespace>` with the Kubernetes cluster namespace in which ArcGIS Enterprise will be deployed to. 

Alternatively, values can be passed in with the `--set` parameter, which will override values.yaml and configure.yaml. You will need to expand the ```helm install``` command to pass in your unique values. An example is shown below:

```
helm install arcgis --namespace <your namespace> \
  -f <full path>/arcgis-enterprise/configure.yaml
  --set image.registry=<your image registry> \
  --set image.username=<your image registry username> \
  --set image.password=<your image registry password> \
  --set image.repository=<your image repository> \
  --set image.tag=<your image tag> \
  --set install.enterpriseFQDN=<your FQDN> \
  --set install.configureWaitTimeMin=15 \
  --set install.context=arcgis \
  --set install.ingress.ingressType=<your Ingress type> \
  --set install.ingress.loadBalancerType=<your load balancer type> \
  --set install.ingress.tls.secretName=<your TLS secret>
  --set configure.enabled=true \
  --set configure.admin.username=<your site administrator username> \
  --set configure.admin.password=<your site administrator password> \
  --set configure.admin.email=<your site administrator email address> \
  --set configure.admin.firstName=<your first name> \
  --set configure.admin.lastName=<your last name> \
  --set configure.securityQuestionIndex=<question number> \
  --set configure.securityQuestionAnswer=<answer> \
  <full path>/arcgis-enterprise \
  --timeout 60m0s
```

#### Track Installation Status 
The following commands can be used to track the installation status. The first command retrieves the pre-install-hook-job pod name, which is needed for the second command to track the status.
	
```
kubectl get pods --namespace <your namespace> --selector=job-name=arcgis-pre-install-hook-job --output=jsonpath='{.items[*].metadata.name}'
```
		
```
kubectl logs --namespace <your namespace> -f arcgis-pre-install-hook-job-xxxxx
```

Once the Helm chart has successfully been installed, you will receive a Url to access your ArcGIS Enterprise organization.

## Updates and Upgrades

Once you have used Helm to deploy and configure ArcGIS Enterprise on Kubernetes, you can use Helm to update or upgrade the software to provide your organization with the latest available ArcGIS Enterprise enhancements and features, ensuring its security, reliability, and performance.

The following describes the differences between updates and upgrades:

- An [update](https://enterprise-k8s.arcgis.com/en/11.1/administer/apply-updates.htm) is narrowly focused and may address performance, security, or functionality issues and bugs. Updates do not introduce new functionality or change the look and feel of the software. For example, an update moves the software from version 11.2.0.5207 to version 11.2.0.5500.

- An [upgrade](https://enterprise-k8s.arcgis.com/en/latest/administer/upgrade-to-a-new-version.htm) is a new version of the software, with new features, improved functionality, and sometimes a different look and feel. For example, an upgrade moves the software from version 11.1 to version 11.2.

### Upgrade ArcGIS Enterprise on Kubernetes
If you have deployed ArcGIS Enterprise 11.1 on Kubernetes using chart v1.1.0, you can upgrade to 11.2 using chart v1.2.0. Chart v1.2.0 will perform the following operations when the `helm upgrade` command is run:

- Runs the ArcGIS Enterprise on Kubernetes 11.1 pre-upgrade.sh script.
- Upgrades the ArcGIS Enterprise on Kubernetes from 11.1 to 11.2.

Before proceeding with an upgrade, a [full system backup](https://enterprise-k8s.arcgis.com/en/latest/administer/backup-and-restore.htm) is recommended. This will allow you to restore your organization to its previous state as necessary.

#### Modify values.yaml
The following values are required by the `helm upgrade`:

- image.registry
- image.username
- image.password
- image.repository
- image.tag
- install.enterpriseFQDN
- install.context
- upgrade.token
- upgrade.targetId
- upgrade.licenseFile
		
#### Upgrade Chart
To begin the upgrade, use the following command:
		
```
helm upgrade arcgis --namespace <your namespace> arcgis-enterprise --timeout 360m0s --debug
```
	
#### Track Upgrade Status 

Use the following commands to track the upgrade status. The first command retrieves the pre-upgrade-hook-job pod name, which is needed for the second command to track the status.
	
```
kubectl get pods --namespace <your namespace> --selector=job-name=arcgis-pre-upgrade-hook-job --output=jsonpath='{.items[*].metadata.name}'
```
		
```
kubectl logs --namespace <your namespace> -f arcgis-pre-upgrade-hook-job-xxxxx
```

### Update ArcGIS Enterprise on Kubernetes
If you have deployed ArcGIS Enterprise on Kubernetes 11.2 using chart v1.2.0, you can use chart v1.2.1 to apply the ArcGIS Enterprise on Kubernetes 11.2 Help Language Pack Update. Chart v1.2.1 will perform the following operation when the helm upgrade command is run:

- Apply the ArcGIS Enterprise on Kubernetes 11.2 Help Language Pack Update.

#### Modify values.yaml
The following values are required by the `helm upgrade`:

- image.registry
- image.username
- image.password
- image.repository
- image.tag
- install.enterpriseFQDN
- install.context
- configure.enabled set to false
- upgrade.token
- upgrade.targetId
		
#### Upgrade Chart
To begin the update, use the following command:
		
```
helm upgrade arcgis --namespace <your namespace> arcgis-enterprise --timeout 60m0s --debug
```
	
#### Track Upgrade Status 

Use the following commands to track the upgrade status. The first command retrieves the pre-upgrade-hook-job pod name, which is needed for the second command to track the status.
	
```
kubectl get pods --namespace <your namespace> --selector=job-name=arcgis-pre-upgrade-hook-job --output=jsonpath='{.items[*].metadata.name}'
```
		
```
kubectl logs --namespace <your namespace> -f arcgis-pre-upgrade-hook-job-xxxxx
```

## Rollback ArcGIS Enterprise on Kubernetes

Using Helm Rollback is not supported. Use the ArcGIS Enterprise [rollback](https://developers.arcgis.com/rest/enterprise-administration/enterprise/rollback.htm) operation to rollback any updates.

## Undeploy ArcGIS Enterprise on Kubernetes

To uninstall ArcGIS Enterprise on Kubernetes using Helm, run the following:

```
helm uninstall arcgis --namespace <your namespace>
```

## Additional Information:

* The release name used for the `helm install` command should be `arcgis`.

* Only one Helm Chart for ArcGIS Enterprise on Kubernetes release per namespace is supported.

* You can opt out of configuring an ArcGIS Enterprise organization by setting `configure.enabled` to false. When `configure.enabled` is set to false, creating an organization can no longer be performed through Helm but can still be performed through ArcGIS Enterprise Manager setup wizard or by using the [configure.sh](https://enterprise-k8s.arcgis.com/en/latest/deploy/create-a-new-organization.htm#ESRI_SECTION1_80617AFCB0B94C4A98406420F2E863C5) script from My Esri.

* When `configure.enabled` is set to true, there is a validation check to ensure https://enterpriseFQDN/context/admin Url is reachable prior to configuring the organization. This can be useful when not using a pre-configured load balancer IP address or in cloud environments where it may take some time for an Application Gateway to respond. You can set the `install.configureWaitTimeMin` value to the amount of time (default is 15 minutes) needed for the admin Url to become available. Additionally, if a randomly generated IP address is assigned to the load balancer, the following command can be used to retrieve the IP address. You can then use this IP address to create a DNS record to map to the enterpriseFQDN before the `install.configureWaitTimeMin` validation check times out.

  ```
  kubectl get service arcgis-ingress-nginx --namespace <your namespace>
  ```
  
  > Note: The load balancer IP address usually gets assigned to the `arcgis-ingress-nginx` service within 1-2 minutes after the `helm install` command is ran.

* Since Helm does not support accessing files outside of the chart folder, you'll need to copy your license file to the `user-inputs` folder.

* The value for `configure.licenseFile` should be a relative path to the file in the `user-inputs` folder.  For example:
    ```
    licenseFile: user-inputs/my-license-file.json
    ```
* The `helm install` command has a default timeout of 300 seconds (5 minutes). The configure process will take longer than the default timeout, so you will need to add a `--timeout 60m0s` flag to the `helm install` command. However, if `configure.enabled` is set to false, the `--timeout` flag is not required.

* The `helm upgrade` command has a default timeout of 300 seconds (5 minutes). The upgrade process will take longer than the default timeout, so you will need to add a --timeout flag to the `helm upgrade` command. The amount of time will vary depending on each environment, however, it is recommended to set it to a minimum of 6 hours `--timeout 360m0s`.

* The `helm upgrade` command can only be used to upgrade an existing 11.1 release to 11.2 if it was originally deployed with chart v1.1.0.

* Pressing `Ctrl+C` during a Helm deployment does not rollback resources applied to the cluster, and the arcgis-pre-install-job pod does not delete itself. The arcgis-pre-install-job pod only deletes itself during a successful deployment.