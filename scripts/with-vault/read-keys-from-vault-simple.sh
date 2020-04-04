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

get_path_key ()
{
  local retval
  retval=$(curl \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "X-Vault-Request: true" \
    -H "X-Vault-Namespace: " \
    -X GET \
    "http://localhost:8200/v1/secret/data/${1}")
  if echo "$retval" | grep '..errors' >/dev/null 2>&1; then
    echo "$retval"
  else
    echo "$retval" | jq ".data.data.${2}"
  fi
  echo
}

get_path_key "mtls/script/client" "key"
get_path_key "mtls/script/client" "crt"
get_path_key "mtls/script/server" "key"
get_path_key "mtls/script/server" "crt"

get_path_key "mtls/script/root-ca" "key"
get_path_key "mtls/script/root-ca" "crt"

echo
