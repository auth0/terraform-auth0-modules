# Ruleset for examples/. Identical to .tflint.hcl minus terraform_documented_variables
# and terraform_documented_outputs: those enforce a documented public interface,
# which matters for a reusable module and not for a leaf configuration whose
# outputs exist only to show what the module returns.
#
# tflint --recursive chdirs into each directory and reads only a .tflint.hcl in
# that directory, so a config at the repo root does not reach modules/ or
# examples/. CI therefore passes --config explicitly, once per tree, which is why
# this second file exists rather than a shared root config.

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
