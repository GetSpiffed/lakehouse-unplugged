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
DBT_CATALOG="${DBT_CATALOG:-polaris}"
DBT_SCHEMA="${DBT_SCHEMA:-dbt_demo}"
POLARIS_URI="${POLARIS_URI:-http://polaris:8181/api/catalog}"
POLARIS_OAUTH2_TOKEN_URL="${POLARIS_OAUTH2_TOKEN_URL:-http://polaris:8181/api/catalog/v1/oauth/tokens}"
ICEBERG_WAREHOUSE="${ICEBERG_WAREHOUSE:-s3://warehouse/polaris}"
S3_ENDPOINT="${S3_ENDPOINT:-http://seaweedfs:8333}"

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
  local region="${AWS_REGION:-us-east-1}"
  echo "⏳ Waiting for SeaweedFS S3 at ${S3_ENDPOINT}..."
  for ((i = 1; i <= retries; i++)); do
    if curl -fsS \
      --aws-sigv4 "aws:amz:${region}:s3" \
      --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" \
      "${S3_ENDPOINT}/" | grep -q '<Name>warehouse</Name>'; then
      echo "✅ SeaweedFS S3 is reachable and warehouse exists"
      return 0
    fi
    sleep 2
  done
  echo "❌ Timed out waiting for SeaweedFS S3"
  return 1
}

export S3_ENDPOINT
wait_for_s3
wait_for_http "Polaris" "http://polaris:8182/q/health"
wait_for_port "Spark Thrift Server" "${DBT_SPARK_HOST}" "${DBT_SPARK_PORT}"

cat <<INFO

🔎 dbt / Spark connection details
- host=${DBT_SPARK_HOST}
- port=${DBT_SPARK_PORT}
- catalog=${DBT_CATALOG}
- schema=${DBT_SCHEMA}
- warehouse=${ICEBERG_WAREHOUSE}
- polaris=${POLARIS_URI}
- polaris_token_url=${POLARIS_OAUTH2_TOKEN_URL}
- s3_endpoint=${S3_ENDPOINT}
INFO

echo "\n🔌 dbt debug (dbt container)"
docker compose run --rm \
  -e DBT_SPARK_HOST="${DBT_SPARK_HOST}" \
  -e DBT_SPARK_PORT="${DBT_SPARK_PORT}" \
  -e DBT_CATALOG="${DBT_CATALOG}" \
  -e DBT_SCHEMA="${DBT_SCHEMA}" \
  dbt debug
