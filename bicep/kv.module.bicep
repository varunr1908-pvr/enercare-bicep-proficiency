@description('Azure region for deployment')
param location string

@description('Key Vault name (must be 3-24 chars; lowercase letters and numbers only; globally unique)')
param keyVaultName string

@description('Tenant ID for access policies (optional if using RBAC)')
@allowed([ '', 'use-rbac' ])
param accessPolicyMode string = 'use-rbac'

@description('SKU name for Key Vault')
@allowed([ 'standard', 'premium' ])
param skuName string = 'standard'

@description('Enables purge protection')
param enablePurgeProtection bool = true

@description('Enables soft delete')
param enableSoftDelete bool = true

@description('Public network access')
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'

// Tags passed from caller
param tags object = {}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    enableSoftDelete: enableSoftDelete
    enablePurgeProtection: enablePurgeProtection
    publicNetworkAccess: publicNetworkAccess
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: subscription().tenantId
    // No access policies here when using RBAC; caller can create separate role assignments if needed
    accessPolicies: accessPolicyMode == 'use-rbac' ? [] : []
  }
}

output name string = kv.name
output resourceId string = kv.id