@description('Azure region for deployment')
param location string = 'canadacentral'

@description('Environment code. Expected: dev, uat, prod, sandbox')
param environment string

@description('Service name per Enercare naming')
param service string

@description('Workload name per Enercare naming')
param workload string

@description('On-prem IPv4 CIDR ranges allowed to access Key Vault')
param onPremIpRanges array

@description('Resource ID of the target Log Analytics Workspace for diagnostics')
param logAnalyticsWorkspaceResourceId string

@allowed([ 'standard' 'premium' ])
@description('Key Vault SKU. Standard is typical.')
param skuName string = 'standard'

//
// Keep naming.bicep for consistency / demonstration
//
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

// ⚠ Resource names cannot use module outputs directly, so we reapply the convention inline.
var keyVaultName = 'kv-${substring(service,0,3)}-${substring(workload,0,2)}-${environment}-${substring(location,0,2)}'

// Normalize environment
var env = toLower(environment)

// RBAC-only auth
var enableRbac = true

// Env-based purge/retention rules
var isProd = env == 'prod' || env == 'production'
var isUat  = env == 'uat' || env == 'test'
var isDev  = env == 'dev'
var isSbx  = env == 'sandbox'

var purgeProtectionEnabled = isProd
var retentionDays = isProd ? 14 : (isUat ? 7 : 7) // dev/sbx forced minimum 7 days

//
// Key Vault
//
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: {
    'enercare:service' : service
    'enercare:workload': workload
    'enercare:environment': env
    'enercare:namingRef': naming.outputs.name // reference output from library
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
      ipRules: [for cidr in onPremIpRanges: { value: cidr }]
      virtualNetworkRules: []
    }
    sku: {
      family: 'A'
      name: skuName
    }
    publicNetworkAccess: 'Enabled'
  }
}

//
// Diagnostics to LAW
//
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ds-${kv.name}'
  scope: kv
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: { enabled: false days: 0 }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: { enabled: false days: 0 }
      }
    ]
  }
}

// Outputs (so _Base can reference)
output keyVaultName string = kv.name
output keyVaultResourceId string = kv.id
output namingLibraryExample string = naming.outputs.name
