targetScope = 'subscription'

// Subscription budget with forecast and actual-spend notifications. Budgets do
// not stop spend — they are the tripwire that makes cost drift visible.
param name string

@description('Budget amount in the billing account currency.')
param amount int

@allowed([
  'Monthly'
  'Quarterly'
  'Annually'
])
param timeGrain string = 'Monthly'

@description('Budget start — must be the first day of a month, e.g. 2026-08-01T00:00:00Z.')
param startDate string

@description('Budget end, e.g. 2030-08-01T00:00:00Z.')
param endDate string

@description('Percentages of the budget at which actual-spend alerts fire.')
param actualThresholds array = [
  80
  100
]

@description('Percentages of the budget at which forecast alerts fire.')
param forecastThresholds array = [
  100
]

@description('Email addresses notified directly by Cost Management.')
param contactEmails array = []

@description('Action group resource IDs notified when a threshold is crossed.')
param actionGroupIds array = []

// Forecast alerts are the useful ones — they fire before the money is gone.
var actualNotifications = toObject(
  actualThresholds,
  threshold => 'actual-${threshold}',
  threshold => {
    enabled: true
    operator: 'GreaterThanOrEqualTo'
    threshold: threshold
    thresholdType: 'Actual'
    contactEmails: contactEmails
    contactGroups: actionGroupIds
  }
)

var forecastNotifications = toObject(
  forecastThresholds,
  threshold => 'forecast-${threshold}',
  threshold => {
    enabled: true
    operator: 'GreaterThanOrEqualTo'
    threshold: threshold
    thresholdType: 'Forecasted'
    contactEmails: contactEmails
    contactGroups: actionGroupIds
  }
)

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: name
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: timeGrain
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    notifications: union(actualNotifications, forecastNotifications)
  }
}

output budgetId string = budget.id
