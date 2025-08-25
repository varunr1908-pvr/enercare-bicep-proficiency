targetScope = 'resourceGroup'

@description('Deployment environment (e.g., dev, uat, prod)')
@allowed([ 'dev', 'uat', 'prod' ])
param environment string

@description('Azure location for all resources unless overridden')
param location string = 'canadacentral'

@description('Service or product area (e.g., enercare)')
param service string

@description('Workload or application name (e.g., gateway)')
param workload string

@description('On-premises IP CIDRs for allow-listing (optional)')
param onPremIpRanges array = []

@description('Log Analytics Workspace resource ID for diagnostics (optional)')
param logAnalyticsWorkspaceResourceId string = ''

@description('Additional tags to apply to all resources (optional)')
param extraTags object = {}

@description('Key Vault SKU')
@allowed([ 'standard', 'premium' ])
param keyVaultSku string = 'standard'

// ------------------------------
// Naming & tags (safe for non-name properties)
// ------------------------------
module naming './naming.bicep' = {
  name: 'naming-helper'
  params: {
    service: service
    workload: workload
    environment: environment
    location: location
  }
}

// Merge common tags
var baseTags = union(naming.outputs.tags, extraTags)

// ------------------------------
// Deterministic Key Vault name (BCP120-safe)
// ------------------------------
var kvBase = toLower('${substring(service, 0, 6)}${substring(workload, 0, 6)}${substring(environment, 0, 4)}${substring(location, 0, 2)}')
var kvHash = uniqueString(subscription().id, resourceGroup().id)
var keyVaultName = substring('${kvBase}${kvHash}', 0, 24)

// ------------------------------
// Key Vault
// ------------------------------
module keyVault './kv.module.bicep' = {
  name: 'kv-deploy'
  params: {
    location: location
    keyVaultName: keyVaultName
    tags: baseTags
    skuName: keyVaultSku
    publicNetworkAccess: 'Enabled'
    enableSoftDelete: true
    enablePurgeProtection: true
  }
}

// Create an *existing* resource symbol for the deployed KV so that extension resources can scope to it.
resource kvTarget 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// ------------------------------
/* Diagnostics for Key Vault (optional)
   Requires a valid Log Analytics Workspace resource ID.
   If not provided, the diagnostic settings resource is skipped.
*/
// ------------------------------
resource kvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceResourceId)) {
  name: 'kv-diags'
  scope: kvTarget
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

// ------------------------------
// Outputs
// ------------------------------
output keyVaultNameOut string = keyVaultName
output keyVaultIdOut string = keyVault.outputs.resourceId
output tagsOut object = baseTags