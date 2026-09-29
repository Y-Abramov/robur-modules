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

# Установщик AbrRoburSetup.exe: не модуль каталога, лежит ассетом в последнем
# релизе Библиотеки (abrmodules). Сайт ссылается на tpm/AbrRoburSetup.exe.
# Нет ассета - пропускаем, каталог от этого не страдает.
SETUP_EXE="AbrRoburSetup.exe"
SETUP_URL="https://github.com/Y-Abramov/abrmodules/releases/latest/download/$SETUP_EXE"
echo "Downloading $SETUP_EXE"
if curl -fsSL -o "mirror/tpm/$SETUP_EXE" "$SETUP_URL"; then
  echo "  sha256: $(sha256sum "mirror/tpm/$SETUP_EXE" | cut -d' ' -f1)"
  echo "  (сверить с sha256 на странице /modules/abr-robur-setup)"
else
  rm -f "mirror/tpm/$SETUP_EXE"
  echo "  WARNING: $SETUP_EXE нет в последнем релизе abrmodules - пропускаю"
fi

echo "Uploading tpm/ ($(ls mirror/tpm | wc -l) files)"
aws s3 sync mirror/tpm "s3://$BUCKET/tpm" \
  --endpoint-url "$ENDPOINT" --acl public-read
