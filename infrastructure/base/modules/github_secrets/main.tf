resource "github_actions_secret" "github_secret" {
  for_each = var.secret_map

  repository      = var.repo_name
  secret_name     = each.key
  plaintext_value = each.value
}
