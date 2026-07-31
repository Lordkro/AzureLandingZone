// CanNotDelete lock on a resource group. A deleted hub takes every spoke's
// egress path with it, so platform groups get a lock; the spoke workload group
// deliberately does not, so teams can tear down and rebuild their own resources.
//
// Note: unlike Terraform, `az deployment ... delete` will not remove this lock
// for you. Remove it explicitly before deleting a locked group.
param name string

@allowed([
  'CanNotDelete'
  'ReadOnly'
])
param level string = 'CanNotDelete'

param notes string = 'Platform resource group — managed by IaC. Remove the lock deliberately before deleting.'

resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: name
  properties: {
    level: level
    notes: notes
  }
}

output lockId string = lock.id
