#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi
DBT_SPARK_HOST="${DBT_SPARK_HOST:-thrift-server}"
DBT_SPARK_PORT="${DBT_SPARK_PORT:-10000}"
DBT_SPARK_PUBLIC_HOST="${DBT_SPARK_PUBLIC_HOST:-localhost}"
DBT_CATALOG="${DBT_CATALOG:-polaris}"
DBT_SCHEMA="${DBT_SCHEMA:-dbt_demo}"
POLARIS_URI="${POLARIS_URI:-http://polaris:8181/api/catalog}"
POLARIS_OAUTH2_TOKEN_URL="${POLARIS_OAUTH2_TOKEN_URL:-http://polaris:8181/api/catalog/v1/oauth/tokens}"
POLARIS_PUBLIC_HEALTH_URL="${POLARIS_PUBLIC_HEALTH_URL:-http://localhost:8182/q/health}"
ICEBERG_WAREHOUSE="${ICEBERG_WAREHOUSE:-s3://warehouse/polaris}"
S3_ENDPOINT="${S3_ENDPOINT:-http://rustfs:9000}"
S3_PUBLIC_ENDPOINT="${S3_PUBLIC_ENDPOINT:-http://localhost:9000}"
S3_BUCKET="${S3_BUCKET:-warehouse}"

wait_for_port() {
  local name="$1"
  local host="$2"
  local port="$3"
  local retries="${4:-60}"

  echo "⏳ Waiting for ${name} on ${host}:${port}..."
  for ((i = 1; i <= retries; i++)); do
    python - <<PY
import socket
import sys
host = "${host}"
port = int("${port}")
try:
    with socket.create_connection((host, port), timeout=2):
        sys.exit(0)
except OSError:
    sys.exit(1)
PY
    if [[ $? -eq 0 ]]; then
      echo "✅ ${name} is reachable"
      return 0
    fi
    sleep 2
  done
  echo "❌ Timed out waiting for ${name}"
  return 1
}

wait_for_http() {
  local name="$1"
  local url="$2"
  local retries="${3:-60}"

  echo "⏳ Waiting for ${name} at ${url}..."
  for ((i = 1; i <= retries; i++)); do
    if curl -fsS "${url}" >/dev/null; then
      echo "✅ ${name} is reachable"
      return 0
    fi
    sleep 2
  done
  echo "❌ Timed out waiting for ${name}"
  return 1
}

wait_for_s3() {
  local retries="${1:-60}"
  local region="${S3_REGION:-us-east-1}"
  echo "⏳ Waiting for S3-compatible object storage at ${S3_PUBLIC_ENDPOINT}..."
  for ((i = 1; i <= retries; i++)); do
    if curl -fsS \
      --aws-sigv4 "aws:amz:${region}:s3" \
      --user "${S3_ACCESS_KEY}:${S3_SECRET_KEY}" \
      "${S3_PUBLIC_ENDPOINT}/" | grep -q "<Name>${S3_BUCKET}</Name>"; then
      echo "✅ S3-compatible object storage is reachable and ${S3_BUCKET} exists"
      return 0
    fi
    sleep 2
  done
  echo "❌ Timed out waiting for S3-compatible object storage"
  return 1
}

export S3_ENDPOINT
wait_for_s3
wait_for_http "Polaris" "${POLARIS_PUBLIC_HEALTH_URL}"
wait_for_port "Spark Thrift Server" "${DBT_SPARK_PUBLIC_HOST}" "${DBT_SPARK_PORT}"

cat <<INFO

🔎 dbt / Spark connection details
- host=${DBT_SPARK_HOST}
- port=${DBT_SPARK_PORT}
- public_host=${DBT_SPARK_PUBLIC_HOST}
- catalog=${DBT_CATALOG}
- schema=${DBT_SCHEMA}
- warehouse=${ICEBERG_WAREHOUSE}
- polaris=${POLARIS_URI}
- polaris_token_url=${POLARIS_OAUTH2_TOKEN_URL}
- s3_endpoint=${S3_ENDPOINT}
- s3_public_endpoint=${S3_PUBLIC_ENDPOINT}
INFO

printf '\n🔌 dbt debug (dbt container)\n'
docker compose run --rm --no-deps --entrypoint dbt \
  -e DBT_SPARK_HOST="${DBT_SPARK_HOST}" \
  -e DBT_SPARK_PORT="${DBT_SPARK_PORT}" \
  -e DBT_CATALOG="${DBT_CATALOG}" \
  -e DBT_SCHEMA="${DBT_SCHEMA}" \
  dbt debug
