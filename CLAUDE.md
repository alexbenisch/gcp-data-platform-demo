# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A GCP data platform demo: Terraform provisions BigQuery and Dataform infrastructure, Dataform transforms raw events into analytics marts, and Looker Studio connects to those marts for dashboarding.

## Deploy / Teardown

```bash
# One-time auth — no terraform.tfvars needed
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

cd terraform
terraform init
terraform apply   # project_id auto-detected from gcloud config

terraform destroy
```

`terraform apply`:
- auto-detects project from `gcloud config` (override with `var.project_id` if needed)
- enables APIs, creates BQ datasets/table, Dataform repo
- grants the Dataform service agent `bigquery.dataEditor` + `bigquery.jobUser`
- writes `dataform/dataform.json` with the resolved project ID
- loads ~3000 synthetic rows via `scripts/load_sample_data.sh`

## Run Dataform pipelines

After `terraform apply`, `dataform/dataform.json` already has the correct project ID. Either use the GCP Console (open `data-platform-demo`, create workspace, upload `dataform/` files, Execute → Run all), or via CLI:

```bash
gcloud dataform repositories workspaces execute \
  --project=$(terraform output -raw project_id) \
  --location=europe-west3 \
  --repository=data-platform-demo \
  --workspace=YOUR_WORKSPACE
```

## Reload sample data manually

```bash
bash scripts/load_sample_data.sh YOUR_PROJECT_ID
```

Generates ~2400–6000 rows of synthetic e-commerce events (30 days) using Python and loads via `bq load --replace`.

## Get the Looker Studio URL

```bash
terraform output looker_studio_url
```

## Architecture

```
raw_events.events  (BigQuery table, Terraform-managed)
       │
       └─► Dataform
             ├── definitions/sources/raw_events.sqlx      (declaration, makes table available via ref())
             ├── definitions/transforms/daily_sessions.sqlx     → marts.daily_sessions
             └── definitions/transforms/revenue_by_channel.sqlx → marts.revenue_by_channel
                                │
                        Looker Studio dashboard
```

**BigQuery layers:**
- `raw_events` dataset — landing zone, managed by Terraform
- `marts` dataset — analytics-ready tables, written by Dataform
- `dataform_assertions` schema — Dataform assertion results

**Dataform key config (`dataform/dataform.json`):** `defaultSchema: "marts"`, `defaultLocation: "EU"`. `defaultDatabase` is written by the `local_file.dataform_config` Terraform resource at apply time — do not edit it manually.

**`daily_sessions`** is partitioned by `event_date`, clustered by `traffic_source` and `country`. Has non-null assertions on `event_date` and `sessions`.

**`revenue_by_channel`** is a rolling 30-day view (no partitioning); non-null assertion on `traffic_source`.

## Defaults

| Setting | Value |
|---|---|
| GCP region | `europe-west3` |
| BigQuery location | `EU` |
| Dataform repo name | `data-platform-demo` |
| Google provider | `~> 5.0` |
| Terraform | `>= 1.5.0` |

Required GCP roles: `roles/bigquery.admin`, `roles/dataform.admin`, `roles/serviceusage.serviceUsageAdmin`.
