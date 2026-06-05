#!/bin/sh
set -eu

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is required}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is required}"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

access_key=$(json_escape "$AWS_ACCESS_KEY_ID")
secret_key=$(json_escape "$AWS_SECRET_ACCESS_KEY")

cat > /tmp/s3-config.json <<JSON
{
  "identities": [
    {
      "name": "lakehouse",
      "credentials": [
        {
          "accessKey": "${access_key}",
          "secretKey": "${secret_key}"
        }
      ],
      "actions": ["Admin", "Read", "List", "Tagging", "Write"]
    }
  ]
}
JSON

exec /usr/bin/weed mini \
  -dir=/data \
  -s3.port=8333 \
  -s3.config=/tmp/s3-config.json \
  -bucket=warehouse \
  -webdav=false \
  -admin.ui=false \
  -s3.port.iceberg=0
