#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
    if python - <<PY
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
    then
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

  echo "⏳ Waiting for authenticated SeaweedFS S3 ListBuckets..."
  for ((i = 1; i <= retries; i++)); do
    if docker compose exec -T jupyter python - <<'PYCODE' >/dev/null 2>&1
import boto3
import os

boto3.client(
    "s3",
    endpoint_url=os.environ.get("S3_ENDPOINT", "http://seaweedfs:8333"),
    aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
    aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
    region_name=os.environ.get("AWS_REGION", "us-east-1"),
).head_bucket(Bucket="warehouse")
PYCODE
    then
      echo "✅ SeaweedFS S3 is ready and warehouse exists"
      return 0
    fi
    sleep 2
  done
  echo "❌ Timed out waiting for SeaweedFS S3"
  return 1
}

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
