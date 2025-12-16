#!/usr/bin/env bash
set -e

MODE=${SPARK_CATALOG_MODE:-filesystem}

echo "▶ Spark catalog mode: ${MODE}"

if [ "$MODE" = "polaris" ]; then
  cp /opt/spark/conf/spark-defaults-polaris.conf /opt/spark/conf/spark-defaults.conf
else
  cp /opt/spark/conf/spark-defaults-filesystem.conf /opt/spark/conf/spark-defaults.conf
fi

exec "$@"
