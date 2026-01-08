#!/usr/bin/env bash
set -e

# Fast-fail curl options to avoid long hangs during devcontainer startup
CURL_OPTS=(--fail --show-error --silent --max-time 5 --connect-timeout 3)

echo "🔎 Verifying Lakehouse Unplugged dev container..."
echo "------------------------------------------------"

# --------------------------------------------------------------------
# 1. Polaris health
# --------------------------------------------------------------------
echo "🔍 Checking Polaris health..."
curl "${CURL_OPTS[@]}" http://polaris:8182/q/health | jq .
echo "✔ Polaris is healthy."
echo ""

# --------------------------------------------------------------------
# 2. Optional: Polaris OAuth token check
# --------------------------------------------------------------------
if [ -n "${POLARIS_CLIENT_ID:-}" ] && [ -n "${POLARIS_CLIENT_SECRET:-}" ]; then
  echo "🔐 Checking Polaris OAuth token endpoint..."

  curl "${CURL_OPTS[@]}" -X POST http://polaris:8181/api/catalog/v1/oauth/tokens \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "grant_type=client_credentials&client_id=${POLARIS_CLIENT_ID}&client_secret=${POLARIS_CLIENT_SECRET}" \
    | jq '.access_token' >/dev/null

  echo "✔ Polaris OAuth token request succeeded."
  echo ""
else
  echo "ℹ️ Polaris credentials not set, skipping OAuth check."
  echo ""
fi

# --------------------------------------------------------------------
# 3. Spark Master UI
# --------------------------------------------------------------------
echo "⚡ Checking Spark Master UI..."
if curl "${CURL_OPTS[@]}" http://spark-master:8080 | grep -q "Spark Master"; then
  echo "✔ Spark master reachable at http://spark-master:8080"
else
  echo "❌ Spark master not reachable."
  exit 1
fi
echo ""

# --------------------------------------------------------------------
# 4. Optional: Spark SQL smoke test (only if spark-sql exists)
# --------------------------------------------------------------------
echo "🧪 Spark SQL smoke test (optional)..."
if command -v spark-sql >/dev/null 2>&1; then
  if timeout 45s spark-sql -S -e "SHOW DATABASES;" >/dev/null; then
    echo "✔ Spark SQL is operational."
  else
    STATUS=$?
    if [ $STATUS -eq 124 ]; then
      echo "❌ Spark SQL check timed out (45s)."
    else
      echo "❌ Spark SQL check failed with exit code ${STATUS}."
    fi
    exit 1
  fi
else
  echo "ℹ️ Skipping Spark SQL check: spark-sql not available in dev container."
  echo "   Use the jupyter service (notebooks) or spark-master for Spark checks."
fi
echo ""

# --------------------------------------------------------------------
# 5. Tooling versions
# --------------------------------------------------------------------
echo "📦 Tooling versions:"

if command -v python3 >/dev/null 2>&1; then
  echo "• Python: $(python3 --version)"
else
  echo "• Python: not found"
fi

if command -v python3 >/dev/null 2>&1 && python3 -c "import pyspark" >/dev/null 2>&1; then
  PYSPARK_VER=$(python3 -c 'import pyspark; print(pyspark.__version__)')
  echo "• PySpark: ${PYSPARK_VER}"
else
  echo "• PySpark: not available"
fi

echo ""
echo "------------------------------------------------"
echo "✅ Dev environment verification complete."
