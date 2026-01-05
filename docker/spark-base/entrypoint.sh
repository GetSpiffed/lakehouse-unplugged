#!/usr/bin/env bash
set -euo pipefail

MODE="${SPARK_CATALOG_MODE:-filesystem}"
CONF_DIR="/opt/spark/conf"

echo "▶ Spark catalog mode: ${MODE}"

case "$MODE" in
  polaris|filesystem) ;;
  *)
    echo "❌ Unknown SPARK_CATALOG_MODE=${MODE} (use polaris or filesystem)"
    exit 1
    ;;
esac

SRC="${CONF_DIR}/spark-defaults-${MODE}.conf"
DST="${CONF_DIR}/spark-defaults.conf"

if [[ ! -f "$SRC" ]]; then
  echo "❌ Missing config: $SRC"
  ls -la "$CONF_DIR"
  exit 1
fi

cp -f "$SRC" "$DST"

echo "✅ Active spark-defaults.conf:"
grep -nE "spark.sql.defaultCatalog|spark.sql.catalog.polaris" "$DST" || true

exec "$@"
