#!/usr/bin/env bash
set -e

echo "🔧 Initialising Jupyter kernel: Python (Lakehouse-Unplugged)"
echo "-----------------------------------------------------------"

KERNEL_NAME="lakehouse-unplugged"
DISPLAY_NAME="Python (Lakehouse-Unplugged)"
KERNEL_DIR="/root/.local/share/jupyter/kernels/${KERNEL_NAME}"

# --------------------------------------------------------------------
# 1. Ensure ipykernel is available
# --------------------------------------------------------------------
python3 -m ipykernel >/dev/null 2>&1 || {
  echo "❌ ipykernel not available"
  exit 1
}

# --------------------------------------------------------------------
# 2. Remove existing kernel (clean state)
# --------------------------------------------------------------------
if [ -d "${KERNEL_DIR}" ]; then
  echo "🧹 Removing existing kernel definition..."
  rm -rf "${KERNEL_DIR}"
fi

# --------------------------------------------------------------------
# 3. Install kernel
# --------------------------------------------------------------------
echo "📦 Installing Jupyter kernel..."
python3 -m ipykernel install \
  --user \
  --name "${KERNEL_NAME}" \
  --display-name "${DISPLAY_NAME}"

# --------------------------------------------------------------------
# 4. Inject Spark-aware environment into kernel
# --------------------------------------------------------------------
echo "⚙️ Configuring kernel environment..."

KERNEL_JSON="${KERNEL_DIR}/kernel.json"

jq '.env += {
  "SPARK_HOME": "/opt/spark",
  "PYSPARK_PYTHON": "python3",
  "SPARK_MASTER": "spark://spark-master:7077",
  "DBT_PROFILES_DIR": "/workspace/dbt",
  "MINIO_ENDPOINT": "http://minio:9000"
}' "${KERNEL_JSON}" > "${KERNEL_JSON}.tmp"

mv "${KERNEL_JSON}.tmp" "${KERNEL_JSON}"

# --------------------------------------------------------------------
# 5. Verification
# --------------------------------------------------------------------
echo "📚 Available Jupyter kernels:"
jupyter kernelspec list

if jupyter kernelspec list | grep -q "${KERNEL_NAME}"; then
  echo "✅ Kernel '${DISPLAY_NAME}' ready."
else
  echo "❌ Kernel registration failed."
  exit 1
fi

echo "-----------------------------------------------------------"
