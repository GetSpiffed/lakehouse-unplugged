#!/usr/bin/env bash
set -euo pipefail

MODE="${SPARK_CATALOG_MODE:-filesystem}"
CONF_DIR="/opt/spark/conf"

: "${PYSPARK_PYTHON:=/opt/py311/bin/python}"
: "${PYSPARK_DRIVER_PYTHON:=/opt/py311/bin/python}"
export PYSPARK_PYTHON PYSPARK_DRIVER_PYTHON

echo "▶ Spark catalog mode: ${MODE}"
echo "python versions: $(${PYSPARK_PYTHON} --version)"

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

: "${S3_ENDPOINT:=http://rustfs:9000}"
: "${S3_REGION:=us-east-1}"
: "${S3_PATH_STYLE_ACCESS:=true}"
: "${S3_SSL_ENABLED:=false}"
: "${POLARIS_CLIENT_ID:=admin}"
: "${POLARIS_CLIENT_SECRET:=password}"

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

sed -i \
  -e "s|__S3_ENDPOINT__|$(escape_sed_replacement "$S3_ENDPOINT")|g" \
  -e "s|__S3_REGION__|$(escape_sed_replacement "$S3_REGION")|g" \
  -e "s|__S3_PATH_STYLE_ACCESS__|$(escape_sed_replacement "$S3_PATH_STYLE_ACCESS")|g" \
  -e "s|__S3_SSL_ENABLED__|$(escape_sed_replacement "$S3_SSL_ENABLED")|g" \
  -e "s|__POLARIS_CLIENT_ID__|$(escape_sed_replacement "$POLARIS_CLIENT_ID")|g" \
  -e "s|__POLARIS_CLIENT_SECRET__|$(escape_sed_replacement "$POLARIS_CLIENT_SECRET")|g" \
  "$DST"

echo "✅ Active spark-defaults.conf:"
grep -nE "spark.sql.defaultCatalog|spark.sql.catalog.polaris" "$DST" \
  | sed -E 's/(credential=).*/\1<redacted>/' || true

exec "$@"
