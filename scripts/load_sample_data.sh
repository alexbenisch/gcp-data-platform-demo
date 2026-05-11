#!/usr/bin/env bash
# load_sample_data.sh – generates synthetic e-commerce events and loads into BigQuery
set -euo pipefail

PROJECT_ID="${1:?Usage: load_sample_data.sh PROJECT_ID}"
DATASET="raw_events"
TABLE="events"
TMPFILE=$(mktemp /tmp/events_XXXXXX.ndjson)

echo "Generating synthetic events for ${PROJECT_ID}..."

python3 - <<'PYEOF' > "$TMPFILE"
import json, random, uuid
from datetime import date, timedelta

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

for row in rows:
    print(json.dumps(row))
PYEOF

ROW_COUNT=$(wc -l < "$TMPFILE")
echo "Loading ${ROW_COUNT} rows into ${DATASET}.${TABLE}..."

bq load \
  --project_id="${PROJECT_ID}" \
  --source_format=NEWLINE_DELIMITED_JSON \
  --replace \
  "${DATASET}.${TABLE}" \
  "${TMPFILE}"

rm -f "$TMPFILE"
echo "Done. Sample data loaded successfully."
