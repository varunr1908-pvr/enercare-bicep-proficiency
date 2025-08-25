targetScope = 'resourceGroup'

param environment string

param location string = 'canadacentral'

param onPremIpRanges array

param logAnalyticsWorkspaceResourceId string

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
