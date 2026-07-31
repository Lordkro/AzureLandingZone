plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Module variables and outputs in this repo are documented in the root
# variables.tf and README; per-module descriptions are added where the meaning is
# not obvious from the name, so this rule is advisory rather than blocking.
rule "terraform_documented_variables" {
  enabled = false
}

rule "terraform_documented_outputs" {
  enabled = false
}
