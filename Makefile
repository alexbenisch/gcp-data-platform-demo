.PHONY: all deploy dataform destroy check

all: deploy

# ── Full deployment: infrastructure + sample data + Dataform pipelines ────────
deploy: check
	cd terraform && terraform init -upgrade -input=false
	cd terraform && terraform apply -auto-approve -input=false
	$(MAKE) dataform

# ── Run Dataform pipelines (re-runnable) ─────────────────────────────────────
dataform: check
	cd dataform && npm install --silent
	@echo '{"projectId":"$(shell cd terraform && terraform output -raw project_id)","location":"EU"}' \
		> dataform/.df-credentials.json
	cd dataform && dataform run .
	@echo ""
	@echo "Looker Studio:"
	@cd terraform && terraform output looker_studio_daily_sessions
	@cd terraform && terraform output looker_studio_revenue_by_channel

# ── Tear down all GCP resources ──────────────────────────────────────────────
destroy: check
	cd terraform && terraform destroy -auto-approve -input=false

# ── Prerequisite check ───────────────────────────────────────────────────────
check:
	@which gcloud     >/dev/null || (echo "ERROR: gcloud not found"   && exit 1)
	@which bq         >/dev/null || (echo "ERROR: bq not found — install google-cloud-cli-bq" && exit 1)
	@which terraform  >/dev/null || (echo "ERROR: terraform not found" && exit 1)
	@which node       >/dev/null || (echo "ERROR: node not found"      && exit 1)
	@which dataform   >/dev/null || (echo "ERROR: dataform not found — run: npm i -g @dataform/cli" && exit 1)
	@which python3    >/dev/null || (echo "ERROR: python3 not found"   && exit 1)
	@gcloud auth application-default print-access-token >/dev/null 2>&1 || \
		(echo "ERROR: No valid ADC credentials — run: gcloud auth application-default login" && exit 1)
