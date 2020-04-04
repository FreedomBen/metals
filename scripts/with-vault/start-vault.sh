#!/usr/bin/env bash

# shellcheck disable=1091
if [ -f common.sh ]; then
  . common.sh
elif [ -f scripts/common.sh ]; then
  . scripts/common.sh
else
  echo "Couldn't find common.sh.  Run from root dir or scripts dir"
fi

echo "Starting Vault..."
start_vault
$PODMAN run \
  --cap-add IPC_LOCK \
  --detach \
  --pod "$PODNAME" \
  --env "VAULT_DEV_ROOT_TOKEN_ID=$VAULT_TOKEN" \
  --name "$VAULT_CONTAINER" \
  "$VAULT_IMAGE"
echo "Done starting vault"
