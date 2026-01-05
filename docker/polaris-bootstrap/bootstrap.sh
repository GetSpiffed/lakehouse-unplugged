#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
}

POLARIS_BASE=${POLARIS_BASE:-http://polaris:8181}
POLARIS_CATALOG_NAME=${POLARIS_CATALOG_NAME:-polaris}
MINIO_ENDPOINT=${MINIO_ENDPOINT:-http://minio:9000}
S3_REGION=${S3_REGION:-us-east-1}
POLARIS_DEFAULT_BASE_LOCATION=${POLARIS_DEFAULT_BASE_LOCATION:-s3://warehouse/polaris}
POLARIS_ALLOWED_PREFIX=${POLARIS_ALLOWED_PREFIX:-s3://warehouse/}
POLARIS_SCOPE=${POLARIS_SCOPE:-PRINCIPAL_ROLE:ALL}

bootstrap_realm=""
bootstrap_client_id="${POLARIS_BOOTSTRAP_CLIENT_ID:-admin}"
bootstrap_client_secret="${POLARIS_BOOTSTRAP_CLIENT_SECRET:-password}"

if [[ -n "${POLARIS_BOOTSTRAP_CREDENTIALS:-}" ]]; then
  IFS=',' read -r bootstrap_realm bootstrap_client_id bootstrap_client_secret <<< "${POLARIS_BOOTSTRAP_CREDENTIALS}"
fi

log "Waiting for Polaris at ${POLARIS_BASE}..."
while true; do
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "${POLARIS_BASE}/api/management/v1/catalogs" || true)
  if [[ "${status_code}" != "000" ]]; then
    break
  fi
  log "Polaris not reachable yet, retrying..."
  sleep 2
done

token=""
log "Requesting OAuth token (realm=${bootstrap_realm:-default}, client_id=${bootstrap_client_id})"
for attempt in $(seq 1 30); do
  response=$(curl -sS -X POST "${POLARIS_BASE}/api/catalog/v1/oauth/tokens" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials&client_id=${bootstrap_client_id}&client_secret=${bootstrap_client_secret}&scope=${POLARIS_SCOPE}") || true

  token=$(echo "${response}" | jq -r '.access_token // empty')
  if [[ -n "${token}" ]]; then
    log "Received access token."
    break
  fi

  log "Token request failed (attempt ${attempt}); retrying..."
  sleep 2
done

if [[ -z "${token}" ]]; then
  log "Failed to obtain access token from Polaris."
  log "Response: ${response}"
  exit 1
fi

log "Checking catalog '${POLARIS_CATALOG_NAME}'..."
catalog_status=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer ${token}" \
  "${POLARIS_BASE}/api/management/v1/catalogs/${POLARIS_CATALOG_NAME}" || true)

if [[ "${catalog_status}" == "404" ]]; then
  log "Catalog not found, creating..."
  payload=$(jq -n \
    --arg name "${POLARIS_CATALOG_NAME}" \
    --arg default_base "${POLARIS_DEFAULT_BASE_LOCATION}" \
    --arg allowed "${POLARIS_ALLOWED_PREFIX}" \
    --arg endpoint "${MINIO_ENDPOINT}" \
    --arg region "${S3_REGION}" \
    '{
      catalog: {
        name: $name,
        type: "INTERNAL",
        properties: {"default-base-location": $default_base},
        storageConfigInfo: {
          storageType: "S3",
          allowedLocations: [$allowed],
          endpoint: $endpoint,
          region: $region,
          pathStyleAccess: true,
          stsUnavailable: true
        }
      }
    }')

  create_status=$(curl -s -o /tmp/polaris_catalog_create.json -w "%{http_code}" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -X POST "${POLARIS_BASE}/api/management/v1/catalogs" \
    -d "${payload}")

  if [[ "${create_status}" != "201" ]]; then
    log "Catalog create failed with status ${create_status}."
    cat /tmp/polaris_catalog_create.json
    exit 1
  fi

  log "Catalog '${POLARIS_CATALOG_NAME}' created."
elif [[ "${catalog_status}" == "200" ]]; then
  log "Catalog '${POLARIS_CATALOG_NAME}' already exists."
else
  log "Unexpected status when checking catalog: ${catalog_status}"
  exit 1
fi

log "Listing catalogs..."
curl -sS -H "Authorization: Bearer ${token}" \
  "${POLARIS_BASE}/api/management/v1/catalogs" | jq

log "Polaris bootstrap completed."
