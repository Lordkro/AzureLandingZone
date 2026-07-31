## What changed

<!-- One or two sentences. What does the deployed estate look like after this? -->

## Why

<!-- The problem or requirement. Link the issue or CAF guidance if relevant. -->

## Blast radius

- [ ] Additive only — no existing resource is modified or replaced
- [ ] Modifies existing resources in place
- [ ] **Forces replacement** of one or more resources (list them below)
- [ ] Changes policy effects from Audit to Deny (may block existing workloads)
- [ ] Changes RBAC, custom roles or management group placement

<!-- If anything but the first box is checked, say what breaks and for how long.
     Firewall, VPN Gateway and Application Gateway replacements mean an outage. -->

## Parity

Both IaC tracks deploy the same architecture — a change to one usually needs the other.

- [ ] Terraform updated
- [ ] Bicep updated
- [ ] Not applicable (explain below)

## Checks

- [ ] `terraform fmt -recursive` / `az bicep build` clean
- [ ] Plan / what-if reviewed in the PR comment above
- [ ] `docs/` updated (architecture, governance, naming, deployment)
- [ ] New parameters have defaults that are safe for a fresh subscription
