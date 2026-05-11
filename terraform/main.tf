data "google_client_config" "current" {}

data "google_project" "current" {
  project_id = local.project_id
}

locals {
  project_id = coalesce(var.project_id, data.google_client_config.current.project)
  labels = {
    env     = "demo"
    managed = "terraform"
  }
}

# ─── Enable required APIs ────────────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "dataform.googleapis.com",
  ])
  project            = local.project_id
  service            = each.key
  disable_on_destroy = false
}

# ─── BigQuery: raw layer ─────────────────────────────────────────────────────
resource "google_bigquery_dataset" "raw" {
  project       = local.project_id
  dataset_id    = "raw_events"
  friendly_name = "Raw Events"
  description   = "Landing zone for synthetic e-commerce event data"
  location      = var.dataset_location
  labels        = local.labels

  depends_on = [google_project_service.apis]
}

resource "google_bigquery_table" "events" {
  project             = local.project_id
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "events"
  deletion_protection = false
  labels              = local.labels

  schema = jsonencode([
    { name = "event_date",      type = "DATE",    mode = "REQUIRED" },
    { name = "event_name",      type = "STRING",  mode = "REQUIRED" },
    { name = "user_pseudo_id",  type = "STRING",  mode = "REQUIRED" },
    { name = "session_id",      type = "STRING",  mode = "NULLABLE" },
    { name = "page_path",       type = "STRING",  mode = "NULLABLE" },
    { name = "traffic_source",  type = "STRING",  mode = "NULLABLE" },
    { name = "country",         type = "STRING",  mode = "NULLABLE" },
    { name = "device_category", type = "STRING",  mode = "NULLABLE" },
    { name = "revenue",         type = "FLOAT64", mode = "NULLABLE" },
  ])
}

# ─── BigQuery: marts layer ───────────────────────────────────────────────────
resource "google_bigquery_dataset" "marts" {
  project       = local.project_id
  dataset_id    = "marts"
  friendly_name = "Data Marts"
  description   = "Transformed, analytics-ready tables produced by Dataform"
  location      = var.dataset_location
  labels        = local.labels

  depends_on = [google_project_service.apis]
}

# ─── Dataform repository ─────────────────────────────────────────────────────
resource "google_dataform_repository" "main" {
  provider = google-beta
  project  = local.project_id
  name     = var.dataform_repository_name
  region   = var.region
  labels   = local.labels

  dynamic "git_remote_settings" {
    for_each = var.git_remote_url != "" ? [1] : []
    content {
      url                                 = var.git_remote_url
      default_branch                      = "main"
      authentication_token_secret_version = ""
    }
  }

  depends_on = [google_project_service.apis]
}

# ─── IAM: Dataform service agent → BigQuery ──────────────────────────────────
resource "google_project_iam_member" "dataform_bq_editor" {
  project    = local.project_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dataform.iam.gserviceaccount.com"
  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "dataform_bq_job_user" {
  project    = local.project_id
  role       = "roles/bigquery.jobUser"
  member     = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-dataform.iam.gserviceaccount.com"
  depends_on = [google_project_service.apis]
}

# ─── Dataform config: write project ID into dataform.json ────────────────────
resource "local_file" "dataform_config" {
  content = jsonencode({
    defaultSchema   = "marts"
    assertionSchema = "dataform_assertions"
    warehouse       = "bigquery"
    defaultDatabase = local.project_id
    defaultLocation = var.dataset_location
  })
  filename        = "${path.module}/../dataform/dataform.json"
  file_permission = "0644"
}

# ─── Sample data loader ──────────────────────────────────────────────────────
resource "null_resource" "load_sample_data" {
  triggers = {
    table_id = google_bigquery_table.events.id
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../scripts/load_sample_data.sh ${local.project_id}"
  }

  depends_on = [google_bigquery_table.events]
}
