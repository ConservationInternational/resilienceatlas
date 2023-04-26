variable "repo_name" {
  type = string
}

variable "secret_map" {
  type = map(string)
  default = {}
}
