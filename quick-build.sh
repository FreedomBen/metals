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

  DEFAULT_RELEASE='116'

  $PODMAN build \
    -t quay.io/freedomben/metals-nginx-116:latest \
    -t quay.io/freedomben/metals-nginx-116:1.0 \
    -t docker.io/freedomben/metals-nginx-116:latest \
    -t docker.io/freedomben/metals-nginx-116:1.0 \
    -f Dockerfile.nginx-116 \
    .

  $PODMAN tag \
    quay.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:latest \
    quay.io/freedomben/metals:latest

  $PODMAN tag \
    docker.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:latest \
    docker.io/freedomben/metals:latest
}

main "$@"
