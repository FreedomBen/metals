#!/usr/bin/env bash

# shellcheck disable=1091
if [ -f common.sh ]; then
  . common.sh
elif [ -f scripts/common.sh ]; then
  . scripts/common.sh
else
  echo "Couldn't find common.sh.  Run from root dir or scripts dir"
fi

  #--env VAULT_ROLE=UJ10 \
  #--env VAULT_KUBERNETES_AUTH_PATH=a/long/thing \
echo "Starting mtls..."
$PODMAN run \
  --detach \
  --user 12345 \
  \
  --env METALS_SSL=on \
  --env METALS_SSL_VERIFY_CLIENT=on \
  --env METALS_DEBUG=true \
  --env VAULT_ADDR=http://localhost:8200 \
  --env VAULT_ROOT_PATH=v1/secret/data \
  --env VAULT_TOKEN="$VAULT_TOKEN" \
  \
  --env METALS_PROXY_PASS_PROTOCOL=http \
  --env METALS_PROXY_PASS_HOST=127.0.0.1 \
  --env METALS_FORWARD_PORT=8080 \
  \
  --env MTLS_VAULT_SSL_CERTIFICATE_KEY=crt \
  --env MTLS_VAULT_SSL_CERTIFICATE_PATH=mtls/script/server \
  \
  --env MTLS_VAULT_SSL_CERTIFICATE_KEY_KEY=key \
  --env MTLS_VAULT_SSL_CERTIFICATE_KEY_PATH=mtls/script/server \
  \
  --env MTLS_VAULT_SSL_TRUSTED_CERTIFICATE_KEY=server \
  --env MTLS_VAULT_SSL_TRUSTED_CERTIFICATE_PATH=mtls/script/trust-chain \
  \
  --env MTLS_VAULT_SSL_CLIENT_CERTIFICATE_KEY=client \
  --env MTLS_VAULT_SSL_CLIENT_CERTIFICATE_PATH=mtls/script/trust-chain  \
  \
  --env METALS_HEALTH_CHECK_PATH=/health \
  \
  --name "$METALS_CONTAINER" \
  --pod "$PODNAME" \
  "$METALS_IMAGE"
echo "Done starting mtls"
