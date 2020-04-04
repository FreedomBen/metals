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

$PODMAN run \
  --detach \
  --pod "$PODNAME" \
  --name "$METALS_EXAMPLE_CONTAINER" \
  "$METALS_EXAMPLE_IMAGE"
