# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A GCP data platform demo: Terraform provisions BigQuery and Dataform infrastructure, Dataform transforms raw events into analytics marts, and Looker Studio connects to those marts for dashboarding.

## Deploy / Teardown

```bash
# One-time auth
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Configure
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Set project_id in terraform.tfvars

# Deploy (enables APIs, creates BQ datasets/table, Dataform repo, loads ~3000 sample rows)
terraform init
terraform plan
terraform apply

# Teardown
terraform destroy
```

`terraform apply` automatically runs `scripts/load_sample_data.sh` via a `null_resource` provisioner — no manual data loading needed.

## Run Dataform pipelines

After `terraform apply`, either use the GCP Console (open the `data-platform-demo` repository, create a workspace, upload `dataform/` files, click Execute → Run all), or via CLI:

```bash
gcloud dataform repositories workspaces execute \
  --project=YOUR_PROJECT_ID \
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

**Dataform key config (`dataform/dataform.json`):** `defaultSchema: "marts"`, `defaultDatabase: "YOUR_PROJECT_ID"`, `defaultLocation: "EU"`. The `YOUR_PROJECT_ID` placeholder must be replaced with the actual GCP project ID before uploading to a Dataform workspace — Dataform does not interpolate this value at runtime.

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
