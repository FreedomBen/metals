#!/usr/bin/env bash

set -e

# shellcheck disable=1091
if [ -f common.sh ]; then
  . common.sh
elif [ -f scripts/common.sh ]; then
  . scripts/common.sh
else
  echo "Couldn't find common.sh.  Run from root dir or scripts dir"
fi

delete_path_key ()
{
  curl \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "X-Vault-Request: true" \
    -H "X-Vault-Namespace: " \
    -H "Content-Type: application/json" \
    -X DELETE \
    "${VAULT_ADDR}/v1/secret/data/$1"
}

delete_path_key "mtls/script/client/key" "key"
delete_path_key "mtls/script/client/crt" "crt"

delete_path_key "mtls/script/server/key" "key"
delete_path_key "mtls/script/server/crt" "crt"

delete_path_key "mtls/script/root-ca/key" "key"
delete_path_key "mtls/script/root-ca/crt" "crt"

echo
