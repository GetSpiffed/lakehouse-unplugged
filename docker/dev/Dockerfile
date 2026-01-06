# -------------------------------------------------------------------
# 🧱 Base image: Python 3.11 (Debian Bookworm)
# Optie A: devcontainer is alleen "driver" + tooling, gebruikt remote Spark cluster
# - GEEN lokale Spark install
# - GEEN Iceberg/Hadoop AWS jars in de devcontainer (voorkomt version conflicts)
# -------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm

# -------------------------------------------------------------------
# 🔧 System deps: Java (nodig voor PySpark driver), git/curl
# -------------------------------------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        openjdk-17-jdk \
        git \
        curl && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# -------------------------------------------------------------------
# 🐍 Python deps (driver-side)
# - pyspark: Python client/driver (connect naar spark://spark-master:7077)
# - dbt + PyHive voor thrift-server later
# -------------------------------------------------------------------
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        ipykernel \
        jupyterlab \
        pyspark==3.5.1 \
        dbt-core==1.8.6 \
        dbt-spark[PyHive]==1.8.0 \
        pandas \
        boto3 && \
    rm -rf /root/.cache/pip

# -------------------------------------------------------------------
# ✅ Pre-register global Jupyter kernel
# -------------------------------------------------------------------
RUN python3 -m ipykernel install \
        --name lakehouse-unplugged \
        --display-name "Python (Lakehouse-Unplugged)" \
        --prefix=/usr/local

# -------------------------------------------------------------------
# 🧩 Ensure kernel exists at runtime (for volume overlays)
# -------------------------------------------------------------------
RUN echo '#!/bin/bash\n' \
         'python3 -m ipykernel install --name lakehouse-unplugged --display-name "Python (Lakehouse-Unplugged)" --prefix=/usr/local > /dev/null 2>&1 || true\n' \
         'exec "$@"' > /usr/local/bin/ensure-kernel.sh && chmod +x /usr/local/bin/ensure-kernel.sh

# -------------------------------------------------------------------
# 📌 Defaults: remote Spark
# (je notebook kan dit overrulen, maar dit helpt)
# -------------------------------------------------------------------
ENV SPARK_MASTER=spark://spark-master:7077
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

# -------------------------------------------------------------------
# 📂 Working directory
# -------------------------------------------------------------------
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/ensure-kernel.sh"]
