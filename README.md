# GCP Data Platform Demo

A deployable reference implementation of a GCP Data Platform built with:

- **Terraform** – infrastructure provisioning (BigQuery, Dataform, APIs, IAM)
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

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.5 | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| gcloud CLI + bq | latest | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) |
| Node.js | >= 18 | [nodejs.org](https://nodejs.org) |
| Dataform CLI | >= 3.0 | `npm i -g @dataform/cli` |
| Python 3 | >= 3.9 | [python.org](https://www.python.org) |

GCP permissions required on your project:
- `roles/bigquery.admin`
- `roles/dataform.admin`
- `roles/serviceusage.serviceUsageAdmin`

---

## Deploy

```bash
# 1. Authenticate
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# 2. Deploy everything with one command
make deploy
```

`make deploy` will:
1. Enable BigQuery and Dataform APIs
2. Create `raw_events` and `marts` datasets and the `events` table
3. Load ~3000 rows of synthetic e-commerce events
4. Create a Dataform repository and wire IAM permissions
5. Run the Dataform pipelines (`daily_sessions`, `revenue_by_channel`)
6. Print the Looker Studio URLs

---

## Looker Studio Dashboard

After `make deploy`, open the printed Looker Studio URLs, or regenerate them any time:

```bash
make dataform
```

Suggested charts:
- **Time series** – sessions + revenue over `event_date`
- **Bar chart** – `revenue_by_channel` by `traffic_source`
- **Geo map** – sessions by `country`
- **Scorecard** – total revenue, conversion rate, avg order value

---

## Teardown

```bash
make destroy
```

---

## Repository Structure

```
├── Makefile                      # deploy / dataform / destroy targets
├── terraform/
│   ├── main.tf                   # BigQuery, Dataform repo, IAM, data loader
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── dataform/
│   ├── dataform.json             # written by terraform apply with real project ID
│   ├── package.json              # @dataform/core dependency
│   └── definitions/
│       ├── sources/raw_events.sqlx
│       └── transforms/
│           ├── daily_sessions.sqlx
│           └── revenue_by_channel.sqlx
└── scripts/
    └── load_sample_data.sh       # generates + loads synthetic events via bq CLI
```
