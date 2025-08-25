param location string = 'canadacentral'

param environment string

param service string

param workload string

param onPremIpRanges array

param logAnalyticsWorkspaceResourceId string

param skuName string = 'standard'

module naming './naming.bicep' = {
  name: 'naming-${uniqueString(resourceGroup().id, service, workload, environment)}'
  params: {
    resourceType: 'kv'
    service: service
    workload: workload
    environment: environment
    location: location
  }
}

var keyVaultName = 'kv-${substring(service,0,3)}-${substring(workload,0,2)}-${environment}-${substring(location,0,2)}'

var env = toLower(environment)

var enableRbac = true

var isProd = env == 'prod' || env == 'production'
var isUat  = env == 'uat' || env == 'test'
var isDev  = env == 'dev'
var isSbx  = env == 'sandbox'

var purgeProtectionEnabled = isProd
var retentionDays = isProd ? 14 : (isUat ? 7 : 7) // dev/sbx forced to 7 days due to AKV minimum

// Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: {
    'enercare:service'    : service
    'enercare:workload'   : workload
    'enercare:environment': env
  }
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: enableRbac
    enabledForTemplateDeployment: false
    enabledForDeployment: false
    enabledForDiskEncryption: false
    softDeleteRetentionInDays: retentionDays
    purgeProtectionEnabled: purgeProtectionEnabled
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [ for cidr in onPremIpRanges: { value: cidr } ]
      virtualNetworkRules: []
    }
    sku: {
      family: 'A'
      name: skuName
    }
    publicNetworkAccess: 'Enabled'
  }
}

// Diagnostics to LAW
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ds-${kv.name}'
  scope: kv
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output keyVaultName string = kv.name
output keyVaultResourceId string = kv.id
output namingLibraryExample string = naming.outputs.name
