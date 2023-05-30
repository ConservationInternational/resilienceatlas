variable "function_name" {
  type        = string
  description = "Name of the cloud function"
}

variable "bucket_location" {
  type        = string
  description = "Name of the cloud function"
  default     = "US"
}

variable "gcp_region" {
  type        = string
  description = "GCP region"
}

variable "function_memory" {
  type        = string
  default     = "256M"
  description = "Max memory made available to the function"
}

variable "max_instance_count" {
  type        = number
  default     = 1
  description = "Max number of instances of the function"
}

variable "runtime" {
  type        = string
  description = "The environment in which the function is executed"
}

variable "entry_point" {
  type        = string
  description = "The point of entry"
}

#variable "zip_path" {
#  type = string
#  description = "Path to the zip file containing the function code"
#}


variable "source_dir" {
  type = string
  description = ""
}
