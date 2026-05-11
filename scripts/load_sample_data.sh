#!/usr/bin/env bash
# load_sample_data.sh – generates synthetic e-commerce events and loads into BigQuery
set -euo pipefail

PROJECT_ID="${1:?Usage: load_sample_data.sh PROJECT_ID}"

echo "Generating and loading synthetic events for ${PROJECT_ID}..."

PYTHON=$(which python3 2>/dev/null || mise which python 2>/dev/null || echo python)

"$PYTHON" - "$PROJECT_ID" <<'PYEOF'
import sys, random, uuid, json
from datetime import date, timedelta
from google.cloud import bigquery

PROJECT_ID = sys.argv[1]
DATASET    = "raw_events"
TABLE      = "events"

PAGES     = ["/", "/shop", "/product/shoes", "/product/bag", "/cart", "/checkout", "/confirmation"]
SOURCES   = ["google", "direct", "instagram", "email", "referral"]
EVENTS    = ["page_view", "page_view", "page_view", "add_to_cart", "purchase", "session_start"]
COUNTRIES = ["DE", "AT", "CH", "NL", "FR"]
DEVICES   = ["desktop", "mobile", "tablet"]

rows = []
base = date.today() - timedelta(days=30)
for day_offset in range(30):
    event_date = (base + timedelta(days=day_offset)).isoformat()
    for _ in range(random.randint(80, 200)):
        event_name = random.choice(EVENTS)
        rows.append({
            "event_date":      event_date,
            "event_name":      event_name,
            "user_pseudo_id":  str(uuid.uuid4())[:16],
            "session_id":      str(uuid.uuid4())[:8],
            "page_path":       random.choice(PAGES),
            "traffic_source":  random.choice(SOURCES),
            "country":         random.choice(COUNTRIES),
            "device_category": random.choice(DEVICES),
            "revenue":         round(random.uniform(29.9, 299.9), 2) if event_name == "purchase" else None,
        })

import os
from google.oauth2.credentials import Credentials as OAuthCredentials

token = os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN")
creds = OAuthCredentials(token=token) if token else None
client = bigquery.Client(project=PROJECT_ID, credentials=creds)
table_ref = f"{PROJECT_ID}.{DATASET}.{TABLE}"

job_config = bigquery.LoadJobConfig(
    write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    source_format=bigquery.SourceFormat.NEWLINE_DELIMITED_JSON,
    autodetect=False,
)

ndjson = "\n".join(json.dumps(r) for r in rows)
job = client.load_table_from_json(rows, table_ref, job_config=job_config)
job.result()

print(f"Done. Loaded {len(rows)} rows into {table_ref}.")
PYEOF
