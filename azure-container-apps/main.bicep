// === Parameters =============================================================

// Container versions, defaults to 'latest'
param serviceControlVersion string = 'latest'
param servicePulseVersion string = 'latest'

// Azure data center for deployment, defaults to the default for the deployment resource group
param location string = resourceGroup().location

// Name for a storage account for a file share for database data
param storageAccountName string

// Existing Azure Service Bus namespace name, and resource group if located outside the deployment resource group
param serviceBusNamespaceName string
param serviceBusResourceGroup string = resourceGroup().name

// Container Registry settings, otherwise Docker Hub may throttle container pulls
param dockerUser string
@secure()
param dockerPass string

// The text of a Particular Software license file
@secure()
param particularLicenseText string = ''

// Azure App Principal for OAuth login & throughput metrics
param azurePrincipalClientId string
@secure()
param azurePrincipalSecretKey string

// === Script =================================================================

// NServiceBus transport type, defaults to the TransportType name for Azure Service Bus
// See https://docs.particular.net/servicecontrol/transports
// Changing to a different value will require additional changes to the bicep script
param transportType string = 'NetStandardAzureServiceBus'

var CommonEnvVars = [
  { name: 'TRANSPORTTYPE', value: transportType }
  { name: 'PARTICULARSOFTWARE_LICENSE', secretRef: 'license' }
  { name: 'CONNECTIONSTRING', secretRef: 'connstr' }
  { name: 'RAVENDB_CONNECTIONSTRING', value: 'http://servicecontrol-db' }
  { name: 'REMOTEINSTANCES', value:'[{"api_uri":"http://audit/api"}]' }
]

var ContainerRegistries = [
  { server: 'docker.io', username: dockerUser, passwordSecretRef: 'dockerpass' }
]

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-11-01' existing = {
  name: serviceBusNamespaceName
  scope: resourceGroup(serviceBusResourceGroup)
}

var serviceBusEndpoint = '${serviceBus.id}/AuthorizationRules/RootManageSharedAccessKey'
var serviceBusKeys = listKeys(serviceBusEndpoint, serviceBus.apiVersion)
var serviceBusConnStr = serviceBusKeys.primaryConnectionString

var Secrets = [
  { name: 'dockerpass', value: dockerPass }
  { name: 'license', value: particularLicenseText }
  { name: 'connstr', value: serviceBusConnStr }
  { name: 'azure-principal-secret', value: azurePrincipalSecretKey }
]

var singleReplica = { minReplicas: 1, maxReplicas: 1 }

func createInternalIngress(port int) object => {
  allowInsecure: true
  clientCertificateMode: 'ignore'
  external: false
  targetPort: port
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Premium_LRS' }
  kind: 'FileStorage'
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    protocolSettings: {
      smb: {
        multichannel: { enabled: false }
      }
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileServices
  name: 'platform-data'
  properties: {
    accessTier: 'Premium'
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'logs-platform-apps'
  location: location
  properties: {
    retentionInDays: 30
    sku: { name: 'PerGB2018' }
  }
}

resource appEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  location: location
  name: 'platform-apps'
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource dbStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: appEnvironment
  name: 'platform-data'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      shareName: 'platform-data'
      accessMode: 'ReadWrite'
      accountKey: storageAccount.listKeys().keys[0].value
    }
  }
}

resource database 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'servicecontrol-db'
  location: location
  dependsOn: [ dbStorage ]
  properties: {
    environmentId: appEnvironment.id
    configuration: {
      secrets: Secrets
      registries: ContainerRegistries
      ingress: createInternalIngress(8080)
    }
    template: {
      containers: [
        {
          name: 'servicecontrol-db'
          image: 'particular/servicecontrol-ravendb:${serviceControlVersion}'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          volumeMounts: [
            {
              mountPath: '/opt/RavenDB/Server/RavenData'
              volumeName: 'platform-data'
            }
          ]
          env: [
            { name: 'RAVEN_Security_UnsecuredAccessAllowed', value: 'PublicNetwork' }
          ]
        }
      ]
      scale: singleReplica
      volumes: [
        {
          name: 'platform-data'
          storageName: 'platform-data'
          storageType: 'AzureFile'
          mountOptions: 'dir_mode=0777,file_mode=0777,uid=1001,gid=1001,mfsymlinks,nobrl'
        }
      ]
    }
  }
}

resource primary 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'servicecontrol'
  location: location
  dependsOn: [ database ]
  properties: {
    environmentId: appEnvironment.id
    configuration: {
      secrets: concat(Secrets, [
        { name: 'licensing-client-id', value: azurePrincipalClientId }
        { name: 'licensing-client-secret', value: azurePrincipalSecretKey }
      ])
      registries: ContainerRegistries
      ingress: createInternalIngress(33333)
    }
    template: {
      containers: [
        {
          name: 'servicecontrol'
          image: 'particular/servicecontrol:${serviceControlVersion}'
          args: [ '--setup-and-run' ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(CommonEnvVars, [
            { name: 'LICENSINGCOMPONENT_ASB_SERVICEBUSNAME', value: serviceBusNamespaceName }
            { name: 'LICENSINGCOMPONENT_ASB_CLIENTID', secretRef: 'licensing-client-id' }
            { name: 'LICENSINGCOMPONENT_ASB_CLIENTSECRET', secretRef: 'licensing-client-secret' }
            { name: 'LICENSINGCOMPONENT_ASB_SUBSCRIPTIONID', value: subscription().subscriptionId }
            { name: 'LICENSINGCOMPONENT_ASB_TENANTID', value: subscription().tenantId }
          ])
        }
      ]
      scale: singleReplica
    }
  }
}

resource audit 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'audit'
  location: location
  dependsOn: [ database ]
  properties: {
    environmentId: appEnvironment.id
    configuration: {
      secrets: Secrets
      registries: ContainerRegistries
      ingress: createInternalIngress(44444)
    }
    template: {
      containers: [
        {
          name: 'audit'
          image: 'particular/servicecontrol-audit:${serviceControlVersion}'
          args: [ '--setup-and-run' ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(CommonEnvVars, [
            { name: 'SERVICECONTROLQUEUEADDRESS', value: 'Particular.ServiceControl' }
          ])
        }
      ]
      scale: singleReplica
    }
  }
}

resource monitoring 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'monitoring'
  location: location
  properties: {
    environmentId: appEnvironment.id
    configuration: {
      secrets: Secrets
      registries: ContainerRegistries
      ingress: createInternalIngress(33633)
    }
    template: {
      containers: [
        {
          name: 'monitoring'
          image: 'particular/servicecontrol-monitoring:${serviceControlVersion}'
          args: [ '--setup-and-run' ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: concat(CommonEnvVars, [
            { name: 'MONITORING_SERVICECONTROLTHROUGHPUTDATAQUEUE', value: 'ServiceControl.ThroughputData' }
          ])
        }
      ]
      scale: singleReplica
    }
  }
}

resource servicepulse 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'servicepulse'
  location: location
  properties: {
    environmentId: appEnvironment.id
    configuration: {
      secrets: Secrets
      registries: ContainerRegistries
      ingress: {
        allowInsecure: true
        clientCertificateMode: 'ignore'
        external: true
        targetPort: 9090
      }
    }
    template: {
      containers: [
        {
          name: 'servicepulse'
          image: 'particular/servicepulse:${servicePulseVersion}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            { name: 'SERVICECONTROL_URL', value: 'http://servicecontrol' }
            { name: 'MONITORING_URL', value: 'http://monitoring' }
          ]
        }
      ]
      scale: singleReplica
    }
  }
}

resource servicepulseAuth 'Microsoft.App/containerApps/authConfigs@2024-03-01' = {
  parent: servicepulse
  name: 'current'
  properties: {
     httpSettings: {
      requireHttps: true
    }
    encryptionSettings: {}
    globalValidation: {
      unauthenticatedClientAction: 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: azurePrincipalClientId
          clientSecretSettingName: 'azure-principal-secret'
          openIdIssuer: '${environment().authentication.loginEndpoint}${subscription().tenantId}/v2.0'
        }
      }
    }
    platform: {
      enabled: true
    }
  }
}
