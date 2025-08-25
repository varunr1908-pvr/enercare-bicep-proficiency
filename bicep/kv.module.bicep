@description('Azure region for deployment')
param location string = 'canadacentral'

@description('Environment code. Expected: dev, uat/test, prod, sandbox (support future envs too).')
param environment string

@description('Service name per Enercare naming (e.g., Integration Technology Service).')
param service string = 'integration-technology'

@description('Workload name per Enercare naming (e.g., Gateway).')
param workload string = 'gateway'

@description('On-prem IPv4 CIDR ranges allowed to access Key Vault. Example: ["203.0.113.0/24", "198.51.100.10/32"]')
param onPremIpRanges array

@description('Resource ID of the target Log Analytics Workspace for diagnostics.')
param logAnalyticsWorkspaceResourceId string

@allowed([
  'standard'
  'premium'
])
@description('Key Vault SKU. Standard is typical.')
param skuName string = 'standard'

/*
  Naming:
  The test mentions a naming.bicep library with a generateName function.
  We treat it as a module that, given inputs, outputs a correctly formatted name.
  Adjust parameter names to match the actual library as needed.
*/
module naming './naming.bicep' = {
  name: 'naming-${uniqueString(resourceGroup().id, service, workload, environment)}'
  params: {
    // These parameter names may need to match your library exactly.
    resourceType: 'kv'               // Microsoft-recommended abbreviation for Key Vault
    service: service
    workload: workload
    environment: environment
    location: location
  }
}

// Fallback if the naming module uses a different output name; adapt if needed.
var keyVaultName = contains(naming.outputs, 'name') ? string(naming.outputs.name) : 'kv-${uniqueString(resourceGroup().id, service, workload, environment)}'

// Normalize environment (lowercase) to keep conditions resilient.
var env = toLower(environment)

// RBAC-only authorization is enabled by setting enableRbacAuthorization = true and not configuring accessPolicies.
var enableRbac = true

// Environment-specific purge & retention logic
// Requirements:
// - PROD: Purge protection ON; retain 14 days
// - UAT/TEST: Purge protection OFF; retain 7 days
// - DEV/SANDBOX: Do NOT persist deleted values (platform constraint: min 7 days; see note below)
var isProd = env == 'prod' || env == 'production'
var isUat  = env == 'uat' || env == 'user-acceptance-testing' || env == 'test' || env == 'testing'
var isDev  = env == 'dev' || env == 'development'
var isSbx  = env == 'sbx' || env == 'sandbox'

// Platform-compliant retention configuration
// If your test environment supports disabling soft-delete (legacy/older API), you can set retention to 0 in Dev/Sandbox.
// Modern AKV enforces min 7 days retention and soft-delete is always on.
var purgeProtectionEnabled = isProd
var retentionDays = isProd ? 14 : (isUat ? 7 : 7) // Dev/Sandbox requested "0", but constrained to 7 by platform.

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: {
    'enercare:service': service
    'enercare:workload': workload
    'enercare:environment': env
  }
  properties: {
    tenantId: subscription().tenantId

    // RBAC-only (no accessPolicies)
    enableRbacAuthorization: enableRbac

    // Explicitly prevent use by other deployment templates/VM/disk enc:
    enabledForTemplateDeployment: false
    enabledForDeployment: false
    enabledForDiskEncryption: false

    // Soft-delete & purge
    // NOTE: soft-delete is implicit/always on in modern API versions; we set retention and purge protection per env
    // Dev/Sandbox "no persist" request is approximated to 7 due to platform minimum.
    softDeleteRetentionInDays: retentionDays
    purgeProtectionEnabled: purgeProtectionEnabled

    // Network ACLs: default deny, allow specified on-prem IPs
    networkAcls: {
      bypass: 'AzureServices'            // allow Azure services (adjust if stricter posture required)
      defaultAction: 'Deny'
      ipRules: [
        for cidr in onPremIpRanges: {
          value: cidr
        }
      ]
      virtualNetworkRules: []            // not specified in test; can be extended if needed
    }

    sku: {
      family: 'A'
      name: skuName
    }

    // Public endpoint stays enabled unless you’re enforcing private endpoints elsewhere.
    // Set publicNetworkAccess to 'Disabled' if moving to Private Endpoints only.
    publicNetworkAccess: 'Enabled'
  }
}

// Diagnostic settings -> Log Analytics (AuditEvent)
resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ds-${kv.name}'
  scope: kv
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output keyVaultName string = kv.name
output keyVaultResourceId string = kv.id