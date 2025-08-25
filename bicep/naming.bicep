// NOTE: These values are for tags/prefixes only. Do NOT use module outputs for resource `name`
// because resource names must be determinable at the start of deployment (BCP120).
// Instead, compute names in the caller and pass them as parameters to modules.

@description('Service name (e.g., enercare, billing)')
param service string

@description('Workload or app name')
param workload string

@description('Environment (dev, uat, prod)')
param environment string

@description('Azure region (e.g., canadacentral)')
param location string

// Common prefix for display names, dashboards, etc.
var displayPrefix = toLower('${substring(service, 0, 6)}-${substring(workload, 0, 6)}-${environment}-${substring(location, 0, 2)}')

// Tags to use across resources
output tags object = {
  service: toLower(service)
  workload: toLower(workload)
  environment: toLower(environment)
  location: toLower(location)
  owner: 'platform'
  managedBy: 'bicep'
}

// Optional: display name prefix (safe to use in non-name properties)
output displayPrefix string = displayPrefix