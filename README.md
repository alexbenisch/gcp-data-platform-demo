# GCP Data Platform Demo

A deployable reference implementation of a GCP Data Platform built with:

- **Terraform** – infrastructure provisioning (BigQuery, Dataform, APIs)
- **Dataform** – SQL-based transformation pipelines with `ref()` dependencies
- **Looker Studio** – BI dashboard connected to BigQuery marts

> Built as a showcase for [Alexander Benisch](https://linkedin.com/in/alexander-benisch-hd) –
> freelance DevOps Engineer & GCP Infrastructure Specialist.

---

## Architecture

```
synthetic events
      │
      ▼
BigQuery: raw_events.events          ← Terraform-provisioned table
      │
      ▼
Dataform Pipelines
  ├── marts.daily_sessions            ← partitioned by date, clustered
  └── marts.revenue_by_channel        ← revenue metrics by channel
      │
      ▼
Looker Studio Dashboard              ← connects to marts dataset
```

---

## Prerequisites

| Tool        | Version  |
|-------------|----------|
| Terraform   | >= 1.5   |
| gcloud CLI  | latest   |
| Python 3    | >= 3.9   |
| bq CLI      | (bundled with gcloud) |

GCP permissions required on your project:
- `roles/bigquery.admin`
- `roles/dataform.admin`
- `roles/serviceusage.serviceUsageAdmin`

---

## Deploy

```bash
# 1. Authenticate and set your project
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# 2. Deploy — no other configuration needed
cd terraform
terraform init
terraform apply
```

This will:
1. Enable BigQuery and Dataform APIs
2. Create `raw_events` and `marts` datasets
3. Create the `events` table with schema
4. Load ~3000 rows of synthetic e-commerce events
5. Create a Dataform repository
6. Grant the Dataform service agent the BigQuery permissions it needs to run
7. Write your project ID into `dataform/dataform.json` (ready to upload)

---

## Run Dataform Pipelines

After `terraform apply`, open [Dataform in the GCP Console](https://console.cloud.google.com/dataform):

1. Open the `data-platform-demo` repository
2. Create a workspace
3. Upload the files from `dataform/` into the workspace (`dataform.json` is already configured with your project ID)
4. Click **Execute** → **Run all**

Alternatively via gcloud CLI:
```bash
gcloud dataform repositories workspaces execute \
  --project=$(terraform output -raw project_id) \
  --location=europe-west3 \
  --repository=data-platform-demo \
  --workspace=YOUR_WORKSPACE
```

---

## Looker Studio Dashboard

After Dataform has run, open the auto-generated link from Terraform output:

```bash
terraform output looker_studio_url
```

Or manually:
1. Go to [Looker Studio](https://lookerstudio.google.com)
2. Create report → BigQuery connector
3. Select project → `marts` dataset
4. Add `daily_sessions` and `revenue_by_channel` tables

Suggested charts:
- **Time series** – sessions + revenue over `event_date`
- **Bar chart** – `revenue_by_channel` by `traffic_source`
- **Geo map** – sessions by `country`
- **Scorecard** – total revenue, conversion rate, avg order value

---

## Teardown

```bash
terraform destroy
```

---

## Repository Structure

```
├── terraform/
│   ├── main.tf               # BigQuery datasets, tables, Dataform repo, data loader
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── dataform/
│   ├── dataform.json         # Dataform project config
│   └── definitions/
│       ├── sources/
│       │   └── raw_events.sqlx       # source declaration
│       └── transforms/
│           ├── daily_sessions.sqlx   # partitioned sessions mart
│           └── revenue_by_channel.sqlx
├── scripts/
│   └── load_sample_data.sh   # generates + loads synthetic events via bq CLI
└── README.md
```
