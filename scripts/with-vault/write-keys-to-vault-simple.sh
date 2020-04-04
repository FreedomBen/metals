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

write_path_key ()
{
  curl \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "X-Vault-Request: true" \
    -H "X-Vault-Namespace: " \
    -H "Content-Type: application/json" \
    -X POST \
    --data "{
              \"data\": {
                \"$2\": \"$3\",
                \"$4\": \"$5\"
              }
            }" \
    "${VAULT_ADDR}/v1/secret/data/$1"
}

file_to_env_var ()
{
  awk '{printf "%s\\n", $0}' "$1"
}


CLIENT_KEY="$(file_to_env_var certs/simple-root-client-server/client.key)"
CLIENT_CRT="$(file_to_env_var certs/simple-root-client-server/client.crt))"

SERVER_KEY="$(file_to_env_var certs/simple-root-client-server/server.key)"
SERVER_CRT="$(file_to_env_var certs/simple-root-client-server/server.crt)"

ROOT_CA_KEY="$(file_to_env_var certs/simple-root-client-server/rootca.key)"
ROOT_CA_CRT="$(file_to_env_var certs/simple-root-client-server/rootca.crt)"

write_path_key "mtls/script/client" \
  "key" "$CLIENT_KEY" \
  "crt" "$CLIENT_CRT"

write_path_key "mtls/script/server" \
  "key" "$SERVER_KEY" \
  "crt" "$SERVER_CRT"

write_path_key "mtls/script/root-ca" \
  "key" "$ROOT_CA_KEY" \
  "crt" "$ROOT_CA_CRT"

echo
