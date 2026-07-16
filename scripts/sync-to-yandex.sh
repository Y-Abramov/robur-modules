#!/usr/bin/env bash
set -euo pipefail

BUCKET="abrmove-modules"
ENDPOINT="https://storage.yandexcloud.net"

rm -rf mirror
mkdir -p mirror/tpm

jq -c '.[]' catalog.json | while read -r entry; do
  tpm_url=$(echo "$entry" | jq -r '.tpm_url')
  filename=$(basename "$tpm_url")
  echo "Downloading $filename from $tpm_url"
  curl -fsSL -o "mirror/tpm/$filename" "$tpm_url"
done

jq --arg base "$ENDPOINT/$BUCKET/tpm" \
  'map(.tpm_url = ($base + "/" + (.tpm_url | split("/") | last)))' \
  catalog.json > mirror/catalog.json

echo "Uploading catalog.json"
aws s3 cp mirror/catalog.json "s3://$BUCKET/catalog.json" \
  --endpoint-url "$ENDPOINT" --acl public-read

echo "Uploading tpm/ ($(ls mirror/tpm | wc -l) files)"
aws s3 sync mirror/tpm "s3://$BUCKET/tpm" \
  --endpoint-url "$ENDPOINT" --acl public-read
