#!/usr/bin/env bash
set -e

# Fast-fail curl options to avoid long hangs during initial container bring-up
CURL_OPTS=(--fail --show-error --silent --max-time 5 --connect-timeout 3)

echo "🚀 Setting up Lakehouse Unplugged dev environment..."
echo "----------------------------------------------------"

# --------------------------------------------------------------------
# 1. Wait for Polaris (management health endpoint)
# --------------------------------------------------------------------
echo "🔍 Waiting for Polaris health check..."

RETRIES=30
while ! curl "${CURL_OPTS[@]}" http://polaris:8182/q/health >/dev/null 2>&1; do
  if [ $RETRIES -eq 0 ]; then
    echo "❌ Polaris not responding after ~60s."
    exit 1
  fi
  echo "⏳ Waiting for Polaris... ($RETRIES retries left)"
  sleep 2
  RETRIES=$((RETRIES-1))
done

echo "✔ Polaris is reachable."

# --------------------------------------------------------------------
# 2. Verify required environment variables
# --------------------------------------------------------------------
echo "🔐 Verifying required environment variables..."

: "${SPARK_MASTER:?Missing SPARK_MASTER}"
: "${DBT_PROFILES_DIR:?Missing DBT_PROFILES_DIR}"

# Polaris creds are optional for now (used later by Trino / tooling)
if [ -n "${POLARIS_CLIENT_ID:-}" ]; then
  echo "ℹ️ Polaris credentials detected (not used by Spark)."
fi

# --------------------------------------------------------------------
# 3. Ensure dbt profile exists
# --------------------------------------------------------------------
PROFILE_FILE="${DBT_PROFILES_DIR}/profiles.yml"

if [ ! -f "$PROFILE_FILE" ]; then
  echo "📝 Creating default dbt profile..."
  mkdir -p "$DBT_PROFILES_DIR"

  cat <<EOF > "$PROFILE_FILE"
default:
  outputs:
    dev:
      type: spark
      method: thrift
      host: thrift-server
      port: 10000
      schema: default
      auth: NONE
  target: dev
EOF
else
  echo "ℹ️ Existing dbt profile found. Leaving as is."
fi

# --------------------------------------------------------------------
# 4. Developer convenience in .bashrc
# --------------------------------------------------------------------
if ! grep -q "Lakehouse-Unplugged environment" /root/.bashrc 2>/dev/null; then
  echo "💡 Adding helper aliases and vars to .bashrc..."

  cat <<'ENVVARS' >> /root/.bashrc

# ------------------------------------------------------------
# Lakehouse-Unplugged environment
# ------------------------------------------------------------
export DBT_PROFILES_DIR=/workspace/dbt
export PYSPARK_PYTHON=python3
export SPARK_HOME=/opt/spark
export PATH=$PATH:$SPARK_HOME/bin

check_polaris() {
  echo "🔍 Polaris health:"
  curl -s http://polaris:8182/q/health | jq
}

check_spark() {
  spark-sql -e "SHOW DATABASES;"
}
ENVVARS
fi

# --------------------------------------------------------------------
# 5. Spark filesystem catalog smoke test
# --------------------------------------------------------------------
echo "⚡ Running Spark filesystem catalog smoke test..."

if timeout 45s spark-sql -S -e "SHOW DATABASES;" >/dev/null; then
  echo "✔ Spark filesystem catalog reachable."
else
  STATUS=$?
  if [ $STATUS -eq 124 ]; then
    echo "❌ Spark catalog check timed out (45s)."
  else
    echo "❌ Spark catalog check failed with exit code ${STATUS}."
  fi
  exit $STATUS
fi

# --------------------------------------------------------------------
# 6. Summary
# --------------------------------------------------------------------
echo "----------------------------------------------------"
echo "🎉 Lakehouse Unplugged dev setup complete."
echo ""
echo "📦 Tooling:"
dbt --version | head -n 3 || true
python3 -c "import pyspark; print('PySpark', pyspark.__version__)" || true
echo ""
echo "💡 Available helpers:"
echo "   check_spark    # Spark connectivity"
echo "   check_polaris  # Polaris health"
echo ""
echo "📁 dbt profile:"
echo "   $(realpath "$PROFILE_FILE")"
