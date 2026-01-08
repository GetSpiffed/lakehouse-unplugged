# -------------------------------------------------------------------
# 🧱 Base image: Python 3.11 (Debian Bookworm)
# Devcontainer = tooling + development (VS Code)
# - Notebooks/PySpark driver draaien in de aparte jupyter service
# - GEEN lokale Spark install
# - GEEN Iceberg/Hadoop AWS jars in de devcontainer (voorkomt version conflicts)
# -------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm

# -------------------------------------------------------------------
# 🔧 System deps: tooling + (light) Java runtime
# -------------------------------------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        git \
        curl \
        jq && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# -------------------------------------------------------------------
# 🐍 Python deps
# -------------------------------------------------------------------
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        pandas \
        boto3 && \
    rm -rf /root/.cache/pip

# -------------------------------------------------------------------
# 📂 Working directory
# -------------------------------------------------------------------
WORKDIR /workspace
