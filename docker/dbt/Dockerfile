FROM python:3.11-slim-bookworm

WORKDIR /usr/app

# Nodig voor git deps + TLS
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      openjdk-17-jre-headless \
 && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# dbt versions pinnen (gelijk aan dev)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
      "dbt-core==1.11.2" \
      "dbt-spark[PyHive]==1.10.0"

# Default: dbt CLI
ENTRYPOINT ["dbt"]
