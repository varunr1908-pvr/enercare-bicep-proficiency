targetScope = 'subscription'

@description('Name of the resource group to create')
param rgName string = 'rg-enercare-test'

@description('Azure region')
param location string = 'canadacentral'

@description('Deployment environment (dev, uat, prod)')
param environment string

@description('On-premises IP CIDR ranges allowed')
param onPremIpRanges array

// Create (or ensure) the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgName
  location: location
}

// Deploy Log Analytics at RG scope (module, not resource-with-scope)
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'loganalytics-${rgName}'
  scope: rg
  params: {
    workspaceName: 'law-${environment}-${uniqueString(rg.id)}'
    location: location
  }
}

// Deploy Key Vault at RG scope
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
