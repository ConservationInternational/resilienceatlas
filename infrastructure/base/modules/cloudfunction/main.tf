resource "google_project_service" "cloud_functions_api" {
  service            = "cloudfunctions.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_build_api" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_logging_api" {
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry_api" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

#
# Zip file
#
resource "random_id" "default" {
  byte_length = 8
}

data "archive_file" "default" {
  type        = "zip"
  output_path = "/tmp/function-${var.function_name}-${random_id.default.hex}.zip"
  source_dir  = var.source_dir
}

#
# Bucket for source code
#
resource "google_storage_bucket" "bucket" {
  name                        = "${var.function_name}-gcf-source"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "object" {
  name   = "${var.function_name}-${timestamp()}.zip"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.default.output_path
}

#
# Cloud function
#
resource "google_cloudfunctions2_function" "function" {
  name        = var.function_name
  location    = var.gcp_region
  description = "a new function"

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    max_instance_count = var.max_instance_count
    available_memory   = var.function_memory
    available_cpu      = 1
    timeout_seconds    = 60
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role    = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloudfunctions2_function.function.location
  project  = google_cloudfunctions2_function.function.project
  service  = google_cloudfunctions2_function.function.service_config[0].service

  policy_data = data.google_iam_policy.noauth.policy_data

  depends_on = [
    google_cloudfunctions2_function.function,
  ]
}
