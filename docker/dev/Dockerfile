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
# 🐍 Python deps
# - dbt + PyHive voor thrift-server later
# -------------------------------------------------------------------
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        dbt-core==1.8.6 \
        dbt-spark[PyHive]==1.8.0 \
        pandas \
        boto3 && \
    rm -rf /root/.cache/pip

# -------------------------------------------------------------------
# 📂 Working directory
# -------------------------------------------------------------------
WORKDIR /workspace
