locals {
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
  service            = each.key
  disable_on_destroy = false
}

# ─── BigQuery: raw layer ─────────────────────────────────────────────────────
resource "google_bigquery_dataset" "raw" {
  dataset_id    = "raw_events"
  friendly_name = "Raw Events"
  description   = "Landing zone for synthetic e-commerce event data"
  location      = var.dataset_location
  labels        = local.labels

  depends_on = [google_project_service.apis]
}

resource "google_bigquery_table" "events" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "events"
  deletion_protection = false
  labels              = local.labels

  schema = jsonencode([
    { name = "event_date",     type = "DATE",      mode = "REQUIRED" },
    { name = "event_name",     type = "STRING",    mode = "REQUIRED" },
    { name = "user_pseudo_id", type = "STRING",    mode = "REQUIRED" },
    { name = "session_id",     type = "STRING",    mode = "NULLABLE" },
    { name = "page_path",      type = "STRING",    mode = "NULLABLE" },
    { name = "traffic_source", type = "STRING",    mode = "NULLABLE" },
    { name = "country",        type = "STRING",    mode = "NULLABLE" },
    { name = "device_category",type = "STRING",    mode = "NULLABLE" },
    { name = "revenue",        type = "FLOAT64",   mode = "NULLABLE" },
  ])
}

# ─── BigQuery: marts layer ───────────────────────────────────────────────────
resource "google_bigquery_dataset" "marts" {
  dataset_id    = "marts"
  friendly_name = "Data Marts"
  description   = "Transformed, analytics-ready tables produced by Dataform"
  location      = var.dataset_location
  labels        = local.labels

  depends_on = [google_project_service.apis]
}

# ─── Dataform repository ─────────────────────────────────────────────────────
resource "google_dataform_repository" "main" {
  name   = var.dataform_repository_name
  region = var.region
  labels = local.labels

  dynamic "git_remote_settings" {
    for_each = var.git_remote_url != "" ? [1] : []
    content {
      url                                 = var.git_remote_url
      default_branch                      = "main"
      authentication_token_secret_version = "" # provide if using private repo
    }
  }

  depends_on = [google_project_service.apis]
}

# ─── Sample data loader ──────────────────────────────────────────────────────
# Loads synthetic data via bq CLI after apply (see scripts/load_sample_data.sh)
resource "null_resource" "load_sample_data" {
  triggers = {
    table_id = google_bigquery_table.events.id
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../scripts/load_sample_data.sh ${var.project_id}"
  }

  depends_on = [google_bigquery_table.events]
}
