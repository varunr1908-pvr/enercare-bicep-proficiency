@description('Azure region for deployment')
param location string

@description('Environment (dev, uat, prod, sandbox)')
param environment string

@description('Service name for naming convention')
param service string

@description('Workload name for naming convention')
param workload string

@description('On-premises IP CIDR ranges allowed')
param onPremIpRanges array

@description('Log Analytics Workspace resource ID')
param logAnalyticsWorkspaceResourceId string

@description('SKU of the Key Vault (standard or premium)')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

// Naming module
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

var keyVaultName = naming.outputs.name
var env = toLower(environment)

// Environment rules
var isProd = env == 'prod' || env == 'production'
var isUat  = env == 'uat' || env == 'test'
var isDev  = env == 'dev' || env == 'development'
var isSbx  = env == 'sandbox'

var purgeProtectionEnabled = isProd
var retentionDays = isProd ? 14 : (isUat ? 7 : 7) // Dev/Sandbox forced to 7 due to Azure min

// Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForTemplateDeployment: false
    enabledForDeployment: false
    enabledForDiskEncryption: false
    softDeleteRetentionInDays: retentionDays
    purgeProtectionEnabled: purgeProtectionEnabled
    sku: {
      family: 'A'
      name: skuName
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        for cidr in onPremIpRanges: {
          value: cidr
        }
      ]
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

// Diagnostics
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ds-${kv.name}'
  scope: kv
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

output keyVaultName string = kv.name