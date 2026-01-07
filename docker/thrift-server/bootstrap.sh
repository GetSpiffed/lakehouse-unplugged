#!/usr/bin/env bash
set -euo pipefail

SPARK_MASTER_URL="${SPARK_MASTER:-spark://spark-master:7077}"
SPARK_MASTER_HOST="${SPARK_MASTER_HOST:-spark-master}"
SPARK_MASTER_PORT="${SPARK_MASTER_PORT:-7077}"
POLARIS_HOST="${POLARIS_HOST:-polaris}"
POLARIS_PORT="${POLARIS_PORT:-8181}"
RETRIES="${BOOTSTRAP_RETRIES:-60}"
SLEEP_SECONDS="${BOOTSTRAP_SLEEP_SECONDS:-2}"

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

wait_for() {
  local host="$1"
  local port="$2"
  local name="$3"

  log "⏳ Waiting for ${name} at ${host}:${port}"
  for attempt in $(seq 1 "$RETRIES"); do
    if (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1; then
      log "✅ ${name} is reachable"
      return 0
    fi
    log "... not ready yet (${attempt}/${RETRIES}), retrying in ${SLEEP_SECONDS}s"
    sleep "$SLEEP_SECONDS"
  done

  log "❌ Timed out waiting for ${name} at ${host}:${port}"
  return 1
}

wait_for "$SPARK_MASTER_HOST" "$SPARK_MASTER_PORT" "Spark master"
wait_for "$POLARIS_HOST" "$POLARIS_PORT" "Polaris REST API"

log "🏗️ Ensuring namespace exists: polaris.default"
/opt/spark/bin/spark-sql --master "$SPARK_MASTER_URL" -e "CREATE NAMESPACE IF NOT EXISTS polaris.default"

log "🚀 Starting Spark Thrift Server"
exec /opt/spark/sbin/start-thriftserver.sh \
  --master "$SPARK_MASTER_URL" \
  --conf spark.app.name=ThriftServer \
  --conf spark.cores.max=2 \
  --conf spark.executor.cores=1 \
  --conf spark.executor.instances=2 \
  --conf spark.executor.memory=1g \
  --conf spark.driver.cores=1 \
  --conf spark.driver.memory=768m \
  --conf spark.sql.shuffle.partitions=8 \
  --conf spark.sql.adaptive.enabled=true \
  --hiveconf hive.server2.authentication=NONE \
  --hiveconf hive.server2.transport.mode=binary
