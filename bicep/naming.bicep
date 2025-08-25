param resourceType string

param service string

param workload string

param environment string

param location string

output name string = '${resourceType}-${substring(service,0,3)}-${substring(workload,0,2)}-${environment}-${substring(location,0,2)}'
