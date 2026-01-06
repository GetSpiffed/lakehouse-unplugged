# ======================================================================
# Base: Apache Spark 3.5.1
# ======================================================================
FROM apache/spark:3.5.1

ARG ICEBERG_VERSION=1.10.0
ARG SPARK_VERSION=3.5
ARG SCALA_VERSION=2.12
ARG HADOOP_VERSION=3.3.4
ARG AWS_SDK_VERSION=1.12.783
ARG POLARIS_SPARK_VERSION=1.2.0-incubating
ARG PYTHON_VERSION=3.11

USER root

# ======================================================================
# System tools & Python
# ======================================================================
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      curl build-essential openjdk-17-jdk jq \
      python${PYTHON_VERSION} python${PYTHON_VERSION}-distutils python3-pip && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    python3 --version && \
    rm -rf /var/lib/apt/lists/*

# Zorg dat executors/driver standaard dezelfde minor gebruiken (kan overschreven worden via spark-defaults.conf)
ENV PYSPARK_PYTHON=/usr/bin/python3 \
    PYSPARK_DRIVER_PYTHON=/usr/bin/python3

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
      pyspark==${SPARK_VERSION} \
      pyiceberg \
      boto3 \
      s3fs \
      dbt-core==1.7.6 \
      "dbt-spark[PyHive]==1.7.1" \
      jupyterlab \
      ipykernel \
      pandas

# ======================================================================
# Spark JARs: Iceberg + AWS + Hadoop S3A
# ======================================================================
RUN mkdir -p /opt/spark/jars && \
    curl -L -o /opt/spark/jars/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}/${ICEBERG_VERSION}/iceberg-spark-runtime-${SPARK_VERSION}_${SCALA_VERSION}-${ICEBERG_VERSION}.jar && \
    curl -L -o /opt/spark/jars/iceberg-aws-bundle-${ICEBERG_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar && \
    curl -L -o /opt/spark/jars/hadoop-aws-${HADOOP_VERSION}.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar && \
    curl -L -o /opt/spark/jars/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar \
      https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar && \
    echo "✓ Iceberg + Hadoop AWS (S3A) jars installed"


# ======================================================================
# Spark configuration variants
# ======================================================================
COPY conf/spark-defaults-filesystem.conf /opt/spark/conf/
COPY conf/spark-defaults-polaris.conf /opt/spark/conf/


# ======================================================================
# Entrypoint
# ======================================================================
COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && \
    chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# ======================================================================
# Environment
# ======================================================================
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    SPARK_HOME=/opt/spark \
    PATH="/opt/spark/bin:/opt/spark/sbin:${PATH}"

WORKDIR /workspace
CMD ["bash"]
