targetScope = 'resourceGroup'

@description('Log Analytics workspace name')
param workspaceName string

@description('Azure region')
param location string

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

output workspaceId string = law.id
