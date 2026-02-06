# Deploying to Azure Container Apps

This [Bicep file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/file) provides an example of deploying [ServiceControl](https://docs.particular.net/servicecontrol/) and [ServicePulse](https://docs.particular.net/servicepulse/) to [Azure Container Apps hosting](https://learn.microsoft.com/en-us/azure/container-apps/overview).

This can be used as a starting point for a deployment script, but should not be used as-is.

> [!WARNING]
> RavenDB [does not support NFS-based file storage](https://ravendb.net/docs/article-page/6.2/csharp/start/installation/running-in-docker-container#requirements), which is the only type of storage that can be mounted to containers using Azure Container Apps. [RavenDB Cloud](https://ravendb.net/cloud) is another option for Azure Container Apps hosted ServiceControl containers.

## Usage

```pwsh
az deployment group create
  --template-file main.bicep
  --resource-group <DEPLOYMENT_RESOURCE_GROUP_NAME>
  --parameters
    serviceControlVersion=latest
    servicePulseVersion=latest
    storageAccountName=<VALUE>>
    serviceBusNamespaceName=<VALUE>
    serviceBusResourceGroup=<VALUE>
    dockerUser=<VALUE>
    dockerPass=<VALUE>
    particularLicenseText=$LicenseText
    azurePrincipalClientId=<VALUE>
    azurePrincipalSecretKey=<VALUE>
```

The [Particular Software license file](https://docs.particular.net/nservicebus/licensing/) can be loaded from the license file:

```sh
# Bash
LicenseText=`cat License.xml`

# PowerShell
$LicenseText = Get-Content License.xml
```

## Implementation details

* Azure Service Bus is used as the NServiceBus transport.
* The only externally-accessible data ingress is the ServicePulse container, which includes a [reverse proxy](https://docs.particular.net/servicepulse/containerization/#reverse-proxy) to serve the ServiceControl and Monitoring APIs.
* The ServicePulse container is protected by authentication via [Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/container-apps/authentication-entra), which requires [additional setup](#entra-principal-setup).
* One instance of the [`servicecontrol-ravendb` container](https://docs.particular.net/servicecontrol/ravendb/containers) is used for both the [`servicecontrol`](https://docs.particular.net/servicecontrol/servicecontrol-instances/deployment/containers) and [`servicecontrol-audit`](https://docs.particular.net/servicecontrol/audit-instances/deployment/containers) containers.
  * _A single database container should not be shared between multiple ServiceControl instances in production scenarios._

## Parameters

| Parameter | Default | Description |
|-|-|-|
| `serviceControlVersion` | `latest` | The tag (version) for ServiceControl. Valid tags can be found on [Docker Hub](https://hub.docker.com/r/particular/servicecontrol/tags). |
| `servicePulseVersion` | `latest` | The tag (version) for ServicePulse. Valid tags can be found on [Docker Hub](https://hub.docker.com/r/particular/servicepulse/tags). |
| `location` | _Resource group default location_ | The Azure data center location for deployment. Defaults to the default location for the resource group targeted by the deployment. |
| `storageAccountName` | _None, Required_ | The name of a storage account to create to host a file share for database storage. Must obey [storage account name requirements](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview#storage-account-name). |
| `serviceBusNamespaceName` | _None, Required_ | The name of an Azure Service Bus namespace. Queues for ServiceControl will be created here. |
| `serviceBusResourceGroup` | _Deployment resource group_ | A resource group name, if the Service Bus namespace is located in a different resource group from the deployment. |
| `dockerUser` | _None, Required_ | A login username for Docker Hub, to prevent throttling when Azure Container Apps attempts to pull the images. |
| `dockerPass` | _None, Required_ | An access token to act as password for Docker Hub |
| `particularLicenseText` | _Empty_ | The Particular Software license text to apply to the ServiceControl services. See [Usage](#usage) above to see how to load this from the `License.xml` file. |
| `azurePrincipalClientId` | _None, Required_ | The Entra ID App Registration Client ID created in the [Entra Principal setup](#entra-principal-setup). |
| `azurePrincipalSecretKey` | _None, Required_ | The Entra ID App Registration Secret Key created in the [Entra Principal setup](#entra-principal-setup). |

## Entra Principal setup

To authenticate users to a publicly-accessible ServicePulse instance, Entra ID can be used to limit access to only users with access to Azure. This requires the creation of an App Registration in Azure.

1. Go to [Enable authentication and authorization in Azure Container Apps with Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/container-apps/authentication-entra) in the Microsoft documentation.
2. Under Option 2, follow the steps under **Create an app registration in Microsoft Entra ID for your container app**, but keep in mind:
    * Before running the Bicep script for the first time, use a temporary App URL of `https://servicepulse.com` and use this where the instructions  mention `<app-url>`.
    * The step to create a client secret is not optional.
    * Stop at the **Enable Microsoft Entra ID in your container app** heading.
3. Fill in parameters for the Bicep script from the previous process:
    * To find the value for the `azurePrincipalClientId` parameter, go to the App Registration's Overview tab and copy the value of the  **Application (client) ID**, which should be a `Guid`.
   * The value for the `azurePrincipalSecretKey` parameter is the client secret generated during the setup process, and can't be shown again after it is first created. To generate a new secret, go to the App Registration's **Certificates & secrets** tab, click on **Client secrets**, then click **New client secret**. Remember that client secrets eventually expire and must be rotated.
4. Give the App Registration permissions to collect throughput data on the Azure Service Bus namespace for licensing purposes:
    1. Navigate to the Azure Service Bus namespace in the Azure Portal.
    2. Click the **Access control (IAM)** tab.
    3. Click **Add** > **Add role assignment**.
    4. Click the **Monitoring Reader** role, then click the **Next** button. This is the minimum role required to read throughput data.
    5. Click **Select members**, select the newly-created App Registration, then click the **Select** button.
    6. Click the **Review + assign** button.
    7. Click the **Review + assign** button again to create the role assignment.
 5. Once the Bicep script has been run and the `servicepulse` container has been created, set the correct App URL to allow the OpenID authentication flow to succeed:
    1. In the deployment resource group, click on the **servicepulse** container.
    2. On the Overview tab, click the button to the right of the **Application Url** to copy the value.
    3. Go to **Microsoft Entra ID** > **App registrations**.
    4. If necessary, click **All applications** and then find and click the App Registration created earlier.
    5. Click **Authentication**.
    6. In the **Web** box, edit the **Redirect URIs** to replace `https://servicepulse.com` with the copied ServicePulse application URL.
        * The final URL should look something like `https://servicepulse.randomname-00000000.regionname.azurecontainerapps.io/.auth/login/aad/callback`
