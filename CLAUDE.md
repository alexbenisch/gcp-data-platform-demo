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

## Known Gotchas

**Terraform provider for Dataform**
`google_dataform_repository` lives in `hashicorp/google-beta`, not the stable `hashicorp/google` provider at v5.x. The resource requires `provider = google-beta` — do not attempt to move it to the stable provider without first verifying it has been promoted to GA.

**ADC vs gcloud credentials**
There are two separate credential sets on this machine. `gcloud auth list` shows the active user account (used by `gcloud` and `bq`). `gcloud auth application-default print-access-token` uses ADC (used by Terraform and the Dataform CLI) — this can expire independently. If ADC is expired:
- For Terraform: `GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token) GOOGLE_PROJECT=$(gcloud config get-value project) terraform apply`
- For Dataform CLI: `GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/legacy_credentials/alexander.benisch@gmail.com/adc.json dataform run .`
- Both require `GOOGLE_PROJECT` / `GOOGLE_APPLICATION_CREDENTIALS` explicitly because the providers cannot infer the project from an access token alone.

**`data.google_client_config.current.project` returns null with a raw access token**
The data source only reflects the project when it is explicitly set in the provider block or via the `GOOGLE_PROJECT` env var. Setting only `GOOGLE_OAUTH_ACCESS_TOKEN` is not enough — always pair it with `GOOGLE_PROJECT`.

**`bq` is not bundled in all gcloud installations**
On Arch Linux the AUR package is split: `google-cloud-cli` does not include `bq`. Install separately with `yay -S google-cloud-cli-bq`. The `gcloud components install bq` command is blocked on package-manager-managed installs.

**`gcloud dataform` component is unavailable on Arch Linux**
The component is not available via `yay`. Use `npm i -g @dataform/cli` instead (Dataform CLI v3).

**Dataform CLI v3 requires `package.json`**
`dataform run` will fail with `dataformCoreVersion must be specified` unless `dataform/package.json` declares `@dataform/core`. The `dataform.json` alone is not enough.

**Dataform CLI requires `.df-credentials.json`**
`dataform run` also requires `dataform/.df-credentials.json` with `{"projectId": "...", "location": "..."}`. This file is gitignored and auto-generated by `make dataform` from `terraform output`.

**`database:` field in SQLX source declarations**
Do not use `database: "${PROJECT_ID}"` in declaration config blocks — Dataform does not substitute shell-style variables there. Omit `database:` entirely and let `defaultDatabase` from `dataform.json` resolve it.

**Looker Studio deep-link URL format**
The URL must include `ds.type=TABLE` and `ds.tableId`. Do not include `c.reportId=new` — it is interpreted as a report ID lookup, not a create-new flag, and causes a "Bericht nicht freigegeben" access error.
