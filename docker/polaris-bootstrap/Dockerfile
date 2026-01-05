FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY bootstrap.sh /app/bootstrap.sh

CMD ["/app/bootstrap.sh"]
