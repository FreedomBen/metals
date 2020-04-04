#!/usr/bin/env bash

set -e

PODMAN=""

die ()
{
  echo "[DIE]: $1"
}

main ()
{
  if [ -n "$1" ]; then 
    PODMAN="$1"
  elif command -v podman; then
    PODMAN="sudo $(command -v podman)"
  elif command -v docker; then
    PODMAN="$(command -v docker)"
  else
    die 'Could not find podman or docker.  Make sure one is installed'
  fi

  $PODMAN build \
    -t quay.io/freedomben/metals:latest \
    -t quay.io/freedomben/metals:1.0 \
    -t docker.io/freedomben/metals:latest \
    -t docker.io/freedomben/metals:1.0 \
    -t quay.io/freedomben/metals-dumb-init:latest \
    -t quay.io/freedomben/metals-dumb-init:1.0 \
    -t docker.io/freedomben/metals-dumb-init:latest \
    -t docker.io/freedomben/metals-dumb-init:1.0 \
    -f Dockerfile.dumb-init \
    .

  $PODMAN build \
    -t quay.io/freedomben/metals-tini:latest \
    -t quay.io/freedomben/metals-tini:1.0 \
    -t docker.io/freedomben/metals-tini:latest \
    -t docker.io/freedomben/metals-tini:1.0 \
    -f Dockerfile.tini \
    .
}

main "$@"
