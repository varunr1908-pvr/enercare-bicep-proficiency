targetScope = 'resourceGroup'

@description('Deployment environment (dev, uat, prod)')
param environment string

@description('Azure region for deployment')
param location string = 'canadacentral'

@description('On-premises IP CIDR ranges allowed')
param onPremIpRanges array

@description('Log Analytics Workspace resource ID for diagnostics')
param logAnalyticsWorkspaceResourceId string

// Call the Key Vault module
module keyVault './kv.module.bicep' = {
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