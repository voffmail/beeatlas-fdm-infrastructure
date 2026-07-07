#!/bin/sh
set -eu

WORKFLOW_FILE="${WORKFLOW_FILE:-/workflows/initial-starter-workflow.json}"
WORKFLOW_NAME="${WORKFLOW_NAME:-Starter workflow for product data import}"
N8N_URL="${N8N_URL:-http://n8n:5678}"

echo "Waiting for n8n at ${N8N_URL}"
until wget -q -O /dev/null "${N8N_URL}/healthz"; do
  echo "n8n is not ready yet; retrying in 2s"
  sleep 2
done

echo "n8n is ready"

if n8n list:workflow 2>/dev/null | grep -Fq "${WORKFLOW_NAME}"; then
  echo "Workflow '${WORKFLOW_NAME}' already exists; skipping import"
  exit 0
fi

echo "Importing workflow from ${WORKFLOW_FILE}"
n8n import:workflow --input="${WORKFLOW_FILE}" --activeState=false
