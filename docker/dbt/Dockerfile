FROM python:3.11-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    openjdk-21-jre-headless \
    git \
    build-essential \
    libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    dbt-core==1.8.6 \
    "dbt-spark[PyHive]==1.8.0"

WORKDIR /workspace

# Laat de container idle blijven
CMD ["tail", "-f", "/dev/null"]
