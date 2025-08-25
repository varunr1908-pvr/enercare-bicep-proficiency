targetScope = 'resourceGroup'

@description('Azure region for deployment')
param location string

@description('Environment (dev, uat, prod, sandbox, etc.)')
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
@allowed(['standard','premium'])
param skuName string = 'standard'

// ---- Name: follow Enercare convention; ensure global uniqueness & <=24 chars ----
var env = toLower(environment)
var base = 'kv-${substring(service,0,3)}-${substring(workload,0,2)}-${env}-${substring(location,0,2)}'
var suffix = toLower(substring(uniqueString(resourceGroup().id), 0, 5))
var kvNameRaw = '${base}-${suffix}'
var kvName = toLower(replace(substring(kvNameRaw, 0, 24), '_', '-'))

// ---- Retention policy by environment ----
var isProd = env == 'prod' || env == 'production'
var isUat  = env == 'uat'  || env == 'test'
var isDev  = env == 'dev'  || env == 'development'
var isSbx  = env == 'sandbox'

// Azure minimum soft-delete retention is 7 days (cannot be 0):
var retentionDays = isProd ? 14 : (isUat ? 7 : 7)

// ---- Key Vault ----
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

    // Purge protection: enable ONLY in prod. For non-prod, omit the property entirely
    // so redeploys never attempt to set it false (disallowed by platform).
    // (Bicep conditional property pattern)
    ...(isProd ? {
      enablePurgeProtection: true
    } : {})

    sku: {
      family: 'A'
      name: toUpper(skuName)
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [ for cidr in onPremIpRanges: { value: cidr } ]
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Enabled'
  }
}

// ---- Diagnostic Settings: send AuditEvent to LAW ----
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ds-${kv.name}'
  scope: kv
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      { category: 'AuditEvent', enabled: true }
    ]
  }
}

output keyVaultName string = kv.name