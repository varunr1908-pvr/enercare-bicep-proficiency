targetScope = 'subscription'

@description('Name of the resource group to create')
param rgName string = 'rg-enercare-test'

@description('Azure region')
param location string = 'canadacentral'

@description('Deployment environment (dev, uat, prod)')
param environment string

@description('On-premises IP CIDR ranges allowed')
param onPremIpRanges array

// Create the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgName
  location: location
}

// Create Log Analytics Workspace
resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'law-${environment}-${uniqueString(rg.id)}'
  location: location
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    sku: {
      name: 'PerGB2018'
    }
  }
  scope: rg
}

// Deploy the Key Vault into the RG
module keyVault './kv.module.bicep' = {
  name: 'kv-${environment}'
  scope: rg
  params: {
    location: location
    environment: environment
    service: 'integration-technology'
    workload: 'gateway'
    onPremIpRanges: onPremIpRanges
    logAnalyticsWorkspaceResourceId: law.id
    skuName: 'standard'
  }
}

output resourceGroupName string = rg.name
output logAnalyticsWorkspaceId string = law.id
output keyVaultName string = keyVault.outputs.keyVaultName