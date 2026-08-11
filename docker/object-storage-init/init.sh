#!/bin/sh
set -eu

: "${S3_ENDPOINT:?S3_ENDPOINT is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${S3_REGION:=us-east-1}"

log() {
  printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

log "Waiting for the S3-compatible object store at ${S3_ENDPOINT}..."
attempt=1
while ! aws --endpoint-url "${S3_ENDPOINT}" s3api list-buckets >/dev/null 2>&1; do
  if [ "${attempt}" -ge 30 ]; then
    log "Timed out waiting for the S3-compatible object store."
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 2
done

if aws --endpoint-url "${S3_ENDPOINT}" s3api head-bucket --bucket "${S3_BUCKET}" >/dev/null 2>&1; then
  log "Bucket '${S3_BUCKET}' already exists."
elif [ "${S3_REGION}" = "us-east-1" ]; then
  log "Creating bucket '${S3_BUCKET}'..."
  aws --endpoint-url "${S3_ENDPOINT}" s3api create-bucket --bucket "${S3_BUCKET}" >/dev/null
else
  log "Creating bucket '${S3_BUCKET}' in region '${S3_REGION}'..."
  aws --endpoint-url "${S3_ENDPOINT}" s3api create-bucket \
    --bucket "${S3_BUCKET}" \
    --create-bucket-configuration "LocationConstraint=${S3_REGION}" >/dev/null
fi

aws --endpoint-url "${S3_ENDPOINT}" s3api head-bucket --bucket "${S3_BUCKET}"
log "Object-storage initialization completed."
