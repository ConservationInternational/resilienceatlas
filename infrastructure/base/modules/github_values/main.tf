resource "github_actions_secret" "github_secret" {
  for_each = var.secret_map

  repository      = var.repo_name
  secret_name     = each.key
  plaintext_value = each.value
}

resource "github_actions_variable" "github_variable" {
  for_each = var.variable_map

  repository    = var.repo_name
  variable_name = each.key
  value         = each.value
}
