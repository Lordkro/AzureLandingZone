// DDoS Network Protection plan. A flat monthly charge covers up to 100 public
// IPs across the tenant, so create one plan per tenant and share it — not one
// per landing zone.
param name string
param location string
param tags object = {}

resource plan 'Microsoft.Network/ddosProtectionPlans@2024-05-01' = {
  name: name
  location: location
  tags: tags
}

output planId string = plan.id
