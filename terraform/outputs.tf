output "project_id" {
  description = "GCP project used for the deployment"
  value       = local.project_id
}

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

output "looker_studio_daily_sessions" {
  description = "Looker Studio – create report from marts.daily_sessions"
  value       = "https://lookerstudio.google.com/reporting/create?ds.connector=bigQuery&ds.type=TABLE&ds.projectId=${local.project_id}&ds.datasetId=marts&ds.tableId=daily_sessions"
}

output "looker_studio_revenue_by_channel" {
  description = "Looker Studio – create report from marts.revenue_by_channel"
  value       = "https://lookerstudio.google.com/reporting/create?ds.connector=bigQuery&ds.type=TABLE&ds.projectId=${local.project_id}&ds.datasetId=marts&ds.tableId=revenue_by_channel"
}
