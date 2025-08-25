targetScope = 'resourceGroup'

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

// ---------- compile-time KV name (no module outputs) ----------
var env = toLower(environment)
var kvName = 'kv-${substring(service,0,3)}-${substring(workload,0,2)}-${env}-${substring(location,0,2)}'

// Environment rules
var isProd = env == 'prod' || env == 'production'
var isUat  = env == 'uat' || env == 'test'
var isDev  = env == 'dev' || env == 'development'
// var isSbx  = env == 'sandbox' // (unused; remove if not needed)

var enablePurgeProtection = isProd
var retentionDays = isProd ? 14 : (isUat ? 7 : 7) // Dev/Sbx 7 (Azure min)

// Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForTemplateDeployment: false
    enabledForDeployment: false
    enabledForDiskEncryption: false
    softDeleteRetentionInDays: retentionDays
    enablePurgeProtection: enablePurgeProtection   // ✅ correct property name
    sku: {
      family: 'A'
      name: toUpper(skuName)                       // STANDARD / PREMIUM
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

// Diagnostics (scoped to the KV resource)
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
