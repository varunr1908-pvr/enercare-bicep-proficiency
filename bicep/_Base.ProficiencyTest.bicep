targetScope = 'subscription'

@description('Name of the resource group to create')
param rgName string = 'rg-enercare-dev'

@description('Azure region')
param location string = 'canadacentral'

@description('Deployment environment (dev, uat, prod, sandbox, etc.)')
param environment string

@description('On-premises IP CIDR ranges allowed')
param onPremIpRanges array

// Create or ensure the RG
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgName
  location: location
}

// Log Analytics (RG-scoped via module)
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics-${rgName}'
  scope: rg
  params: {
    workspaceName: 'law-${environment}-${uniqueString(rg.id)}'
    location: location
  }
}

// Key Vault (RG-scoped via module)
module keyVault './kv.module.bicep' = {
  name: 'kv-${environment}'
  scope: rg
  params: {
    location: location
    environment: environment
    service: 'integration-technology'
    workload: 'gateway'
    onPremIpRanges: onPremIpRanges
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.workspaceId
    skuName: 'standard'
  }
}

output resourceGroupName string = rg.name
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output keyVaultName string = keyVault.outputs.keyVaultName