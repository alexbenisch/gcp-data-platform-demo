output "bigquery_raw_dataset" {
  description = "BigQuery raw dataset ID"
  value       = google_bigquery_dataset.raw.dataset_id
}

output "bigquery_marts_dataset" {
  description = "BigQuery marts dataset ID"
  value       = google_bigquery_dataset.marts.dataset_id
}

output "dataform_repository" {
  description = "Dataform repository name"
  value       = google_dataform_repository.main.name
}

output "looker_studio_url" {
  description = "Looker Studio base URL – open and connect to the marts dataset"
  value       = "https://lookerstudio.google.com/reporting/create?c.reportId=new&ds.connector=bigQuery&ds.projectId=${var.project_id}&ds.datasetId=marts"
}
