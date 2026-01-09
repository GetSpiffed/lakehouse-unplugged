FROM python:3.11-slim

WORKDIR /usr/app

# Handig voor dbt deps + SSL
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "dbt-core" "dbt-spark[PyHive]"

# optioneel: default command blijft dbt, maar je kunt 'm ook overschrijven in compose
ENTRYPOINT ["dbt"]
