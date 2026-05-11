# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A GCP data platform demo: Terraform provisions BigQuery and Dataform infrastructure, Dataform transforms raw events into analytics marts, and Looker Studio connects to those marts for dashboarding.

## Deploy / Teardown

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

make deploy    # full deploy: terraform + dataform pipelines
make dataform  # re-run pipelines only
make destroy   # tear down all GCP resources
```

`make deploy` runs `terraform apply` (auto-detects project from gcloud config) then `make dataform`.

If ADC credentials are expired, pass the token explicitly to terraform:
```bash
GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token) \
GOOGLE_PROJECT=$(gcloud config get-value project) \
terraform -chdir=terraform apply -auto-approve
```

`make dataform` auto-generates `dataform/.df-credentials.json` from terraform output, installs npm deps, and runs `dataform run .` using ADC.

## Reload sample data manually

```bash
bash scripts/load_sample_data.sh YOUR_PROJECT_ID
```

## Get Looker Studio URLs

```bash
cd terraform && terraform output looker_studio_daily_sessions
cd terraform && terraform output looker_studio_revenue_by_channel
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

**`revenue_by_channel`** has no partitioning; non-null assertion on `traffic_source`.

## Defaults

| Setting | Value |
|---|---|
| GCP region | `europe-west3` |
| BigQuery location | `EU` |
| Dataform repo name | `data-platform-demo` |
| Google provider | `~> 5.0` |
| Terraform | `>= 1.5.0` |

Required GCP roles: `roles/bigquery.admin`, `roles/dataform.admin`, `roles/serviceusage.serviceUsageAdmin`.
