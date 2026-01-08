variable "region" {
  type        = string
  description = "The GCP region to deploy service into"
}

variable "name" {
  type = string
  description = "Name to use on resources"
}

variable "domain" {
  type = string
  description = "Base domain for the DNS zone"
}

variable "histogram_service_name" {
  type = string
  description = "Name of the histogram Cloud Run service"
}

variable "download_image_service_name" {
  type = string
  description = "Name of the download_image Cloud Run service"
}

variable "raster_interaction_service_name" {
  type = string
  description = "Name of the raster_interaction Cloud Run service"
}
