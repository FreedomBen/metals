#!/usr/bin/env bash

# This is here for reproducibility.  
# I would suggest using pod.yaml unless you have a need to start over

set -e

# shellcheck disable=1091
if [ -f common.sh ]; then
  . common.sh
elif [ -f scripts/common.sh ]; then
  . scripts/common.sh
else
  echo "Couldn't find common.sh.  Run from root dir or scripts dir"
fi

create_pod ()
{
  echo "Creating pod..."
  $PODMAN pod create \
    --name "$PODNAME" \
    -p 8080:8080 \
    -p 8200:8200 \
    -p 8443:8443
  echo "Done creating pod"
}

start_vault ()
{
  echo "Starting Vault..."
  $PODMAN run \
    --cap-add IPC_LOCK \
    --detach \
    --pod "$PODNAME" \
    --env "VAULT_DEV_ROOT_TOKEN_ID=$VAULT_TOKEN" \
    --name "$VAULT_CONTAINER" \
    "$VAULT_IMAGE"
  echo "Done starting vault"
}

start_mtls_example ()
{
  echo "starting example service..."
  $PODMAN run \
    --detach \
    --pod "$PODNAME" \
    --name "$METALS_EXAMPLE_CONTAINER" \
    "$METALS_EXAMPLE_IMAGE"
  echo "Done starting example service"
}

start_mtls ()
{
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
}

import_pod ()
{
  $PODMAN play kube "$PODFILE"
}

export_pod ()
{
  # shellcheck disable=2024
  $PODMAN generate kube "$PODNAME" > "$PODFILE"
}

main ()
{
  create_pod
  start_vault
  start_mtls_example
  start_mtls
  # export_pod
}

main "$@"
