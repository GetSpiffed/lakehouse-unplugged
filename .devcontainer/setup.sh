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

# Polaris creds are optional for now (used later by Trino / tooling)
if [ -n "${POLARIS_CLIENT_ID:-}" ]; then
  echo "ℹ️ Polaris credentials detected (not used by dev setup script)."
fi

# --------------------------------------------------------------------
# 3. Developer convenience in .bashrc
# --------------------------------------------------------------------
if ! grep -q "Lakehouse-Unplugged environment" /root/.bashrc 2>/dev/null; then
  echo "💡 Adding helper aliases and vars to .bashrc..."

  cat <<'ENVVARS' >> /root/.bashrc

# ------------------------------------------------------------
# Lakehouse-Unplugged environment
# ------------------------------------------------------------
# Only set Spark env if Spark is actually present in this container
if [ -x /opt/spark/bin/spark-submit ]; then
  export SPARK_HOME=/opt/spark
  export PATH=$PATH:$SPARK_HOME/bin
fi

check_polaris() {
  echo "🔍 Polaris health:"
  curl -s http://polaris:8182/q/health | jq
}

check_spark() {
  if command -v spark-sql >/dev/null 2>&1; then
    spark-sql -e "SHOW DATABASES;"
  else
    echo "ℹ️ spark-sql not available in this container."
    echo "   Use the jupyter service (notebooks) or spark-master for Spark checks."
  fi
}
ENVVARS
fi

# --------------------------------------------------------------------
# 4. Spark smoke test (optional; skip if spark-sql not present)
# --------------------------------------------------------------------
echo "⚡ Spark smoke test (optional)..."

if command -v spark-sql >/dev/null 2>&1; then
  if timeout 45s spark-sql -S -e "SHOW DATABASES;" >/dev/null; then
    echo "✔ Spark reachable from dev container."
  else
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
      echo "❌ Spark catalog check timed out (45s)."
    else
      echo "❌ Spark catalog check failed with exit code ${STATUS}."
    fi
    exit $STATUS
  fi
else
  echo "ℹ️ Skipping Spark smoke test: spark-sql not installed in dev container."
fi

# --------------------------------------------------------------------
# 5. Summary
# --------------------------------------------------------------------
echo "----------------------------------------------------"
echo "🎉 Lakehouse Unplugged dev setup complete."
echo ""
echo "📦 Tooling:"

if python3 -c "import pyspark" >/dev/null 2>&1; then
  python3 -c "import pyspark; print('PySpark', pyspark.__version__)"
else
  echo "• PySpark: not available (OK – notebooks run in the jupyter service)"
fi

echo ""
echo "💡 Available helpers:"
echo "   check_spark    # Spark connectivity (if spark-sql installed)"
echo "   check_polaris  # Polaris health"
