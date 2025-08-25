@description('Resource type abbreviation (e.g., kv)')
param resourceType string

@description('Service name')
param service string

@description('Workload name')
param workload string

@description('Environment')
param environment string

@description('Location')
param location string

// Example: kv-int-gw-dev-cc
output name string = '${resourceType}-${substring(service,0,3)}-${substring(workload,0,2)}-${environment}-${substring(location,0,2)}'
