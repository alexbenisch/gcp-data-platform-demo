variable "project_id" {
  description = "GCP Project ID. Defaults to the active gcloud project if not set."
  type        = string
  default     = null
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west3"
}

variable "dataset_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "EU"
}

variable "dataform_repository_name" {
  description = "Name of the Dataform repository"
  type        = string
  default     = "data-platform-demo"
}

variable "git_remote_url" {
  description = "Git remote URL for Dataform repository (optional)"
  type        = string
  default     = ""
}
