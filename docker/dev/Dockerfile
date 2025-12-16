# -------------------------------------------------------------------
# 🧱 Base image: Python 3.11 (Debian Bookworm)
# -------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm

# -------------------------------------------------------------------
# 🔧 Install system dependencies: Java + base tools (including curl for Polaris)
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
# 🐍 Python dependencies (dbt, Spark, Jupyter, utils)
# -------------------------------------------------------------------
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        ipykernel \
        jupyterlab \
        pyspark==3.5.2 \
        dbt-core==1.8.6 \
        dbt-spark[PyHive]==1.8.0 \
        pandas \
        boto3 && \
    rm -rf /root/.cache/pip

# -------------------------------------------------------------------
# 🧠 Install Apache Spark (for PySpark gateway)
# -------------------------------------------------------------------
ENV SPARK_VERSION=3.5.1 \
    SPARK_HOME=/opt/spark
RUN echo "⬇️  Downloading Spark ${SPARK_VERSION}..." && \
    curl -L --retry 5 --retry-delay 10 --continue-at - \
      https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz \
      -o /tmp/spark.tgz && \
    echo "📦 Extracting Spark..." && \
    tar -xzf /tmp/spark.tgz -C /opt && \
    mv /opt/spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME} && \
    rm /tmp/spark.tgz
ENV PATH="${SPARK_HOME}/bin:${PATH}"

# -------------------------------------------------------------------
#  🧊 Add Iceberg + Hadoop AWS JARs + AWS SDK v2 (same as Spark cluster)
# -------------------------------------------------------------------
RUN mkdir -p /opt/spark/jars && \
    # Iceberg Spark Runtime
    curl -L -o /opt/spark/jars/iceberg-spark-runtime-3.5_2.12-1.5.2.jar \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-3.5_2.12/1.5.2/iceberg-spark-runtime-3.5_2.12-1.5.2.jar && \
    # Iceberg AWS I/O
    curl -L -o /opt/spark/jars/iceberg-aws-1.5.2.jar \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws/1.5.2/iceberg-aws-1.5.2.jar && \
    # Hadoop AWS (needs SDK v1)
    curl -L -o /opt/spark/jars/hadoop-aws-3.3.4.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    # AWS SDK v1 (for Hadoop)
    curl -L -o /opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar \
      https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    # AWS SDK v2 bundle (for Iceberg AWS module)
    curl -L -o /opt/spark/jars/aws-sdk-v2-bundle.jar \
      https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.21.1/bundle-2.21.1.jar

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
# 📂 Working directory
# -------------------------------------------------------------------
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/ensure-kernel.sh"]