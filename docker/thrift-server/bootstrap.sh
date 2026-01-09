#!/usr/bin/env bash
set -euo pipefail

SPARK_MASTER_URL="${SPARK_MASTER:-spark://spark-master:7077}"
SPARK_MASTER_HOST="${SPARK_MASTER_HOST:-spark-master}"
SPARK_MASTER_PORT="${SPARK_MASTER_PORT:-7077}"
POLARIS_HOST="${POLARIS_HOST:-polaris}"
POLARIS_PORT="${POLARIS_PORT:-8181}"
RETRIES="${BOOTSTRAP_RETRIES:-60}"
SLEEP_SECONDS="${BOOTSTRAP_SLEEP_SECONDS:-2}"

# Belangrijk: absolute paden, en NIET /workspace (dat is shared volume en geeft locks)
SPARK_WAREHOUSE_DIR="${SPARK_WAREHOUSE_DIR:-/tmp/spark-warehouse}"
DERBY_HOME="${DERBY_HOME:-/tmp/derby}"

log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"; }

wait_for() {
  local host="$1" port="$2" name="$3"
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

log "📁 Preparing local dirs (absolute paths)"
mkdir -p "$SPARK_WAREHOUSE_DIR" "$DERBY_HOME" || true

# Zorg dat deze call ook niet via Hive/Derby gaat
log "🏗️ Ensuring namespace exists in default catalog (polaris): default"
 /opt/spark/bin/spark-sql \
  --master "$SPARK_MASTER_URL" \
  --conf spark.sql.defaultCatalog=polaris \
  --conf spark.sql.catalogImplementation=in-memory \
  --conf spark.sql.warehouse.dir="file:${SPARK_WAREHOUSE_DIR}" \
  --conf "spark.driver.extraJavaOptions=-Dderby.system.home=${DERBY_HOME}" \
  -e "CREATE NAMESPACE IF NOT EXISTS default"

log "🚀 Starting Spark Thrift Server (Polaris-first, no Hive metastore/Derby)"
/opt/spark/sbin/start-thriftserver.sh \
  --master "$SPARK_MASTER_URL" \
  --name ThriftServer \
  --conf spark.app.name=ThriftServer \
  --conf spark.driver.host=thrift-server \
  --conf spark.driver.bindAddress=0.0.0.0 \
  --conf spark.sql.defaultCatalog=polaris \
  --conf spark.sql.catalogImplementation=in-memory \
  --conf spark.sql.warehouse.dir="file:${SPARK_WAREHOUSE_DIR}" \
  --conf spark.sql.shuffle.partitions=8 \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.cores.max=2 \
  --conf spark.executor.cores=1 \
  --conf spark.executor.instances=2 \
  --conf spark.executor.memory=1g \
  --conf spark.driver.cores=1 \
  --conf spark.driver.memory=768m \
  --conf "spark.driver.extraJavaOptions=-Dderby.system.home=${DERBY_HOME}" \
  --conf "spark.executor.extraJavaOptions=-Dderby.system.home=${DERBY_HOME}" \
  --hiveconf hive.server2.authentication=NONE \
  --hiveconf hive.server2.transport.mode=binary

LOG_GLOB="/opt/spark/logs/spark--org.apache.spark.sql.hive.thriftserver.HiveThriftServer2-*.out"
log "📄 Tailing thriftserver logs: ${LOG_GLOB}"

for attempt in $(seq 1 30); do
  ls -1 ${LOG_GLOB} >/dev/null 2>&1 && break
  sleep 1
done

ls -la /opt/spark/logs || true
tail -F ${LOG_GLOB}
