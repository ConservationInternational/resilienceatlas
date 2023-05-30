output "function_uri" {
  value = google_cloudfunctions2_function.function.service_config[0].uri
}

locals {
  service_name_split = split("/", google_cloudfunctions2_function.function.service_config[0].service)
}

output "function_service_name" {
  value = element(local.service_name_split, length(local.service_name_split)-1)
}
