targetScope = 'resourceGroup'

@description('Deployment environment (dev, uat, prod)')
param environment string

@description('Location')
param location string = 'canadacentral'

@description('On-prem IP CIDRs')
param onPremIpRanges array

@description('Log Analytics Workspace Resource ID')
param logAnalyticsWorkspaceResourceId string

// Call the Key Vault module
module kv './kv.module.bicep' = {
  name: 'kv-${environment}'
  params: {
    location: location
    environment: environment
    service: 'integration-technology'
    workload: 'gateway'
    onPremIpRanges: onPremIpRanges
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    skuName: 'standard'
  }
}

output keyVaultName string = kv.outputs.keyVaultName
output keyVaultResourceId string = kv.outputs.keyVaultResourceId
output namingConvention string = kv.outputs.namingLibraryExample