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
    -t quay.io/freedomben/metals-nginx-116:0.1.0 \
    -t quay.io/freedomben/metals-nginx-116:0.1 \
    -t docker.io/freedomben/metals-nginx-116:0.1.0 \
    -t docker.io/freedomben/metals-nginx-116:0.1 \
    -f Dockerfile.nginx-116 \
    .

  $PODMAN build \
    -t quay.io/freedomben/metals-nginx-114:0.1.0 \
    -t quay.io/freedomben/metals-nginx-114:0.1 \
    -t docker.io/freedomben/metals-nginx-114:0.1.0 \
    -t docker.io/freedomben/metals-nginx-114:0.1 \
    -f Dockerfile.nginx-114 \
    .

  $PODMAN build \
    -t quay.io/freedomben/metals-nginx-117:0.1.0 \
    -t quay.io/freedomben/metals-nginx-117:0.1 \
    -t docker.io/freedomben/metals-nginx-117:0.1.0 \
    -t docker.io/freedomben/metals-nginx-117:0.1 \
    -f Dockerfile.nginx-117 \
    .

  $PODMAN build \
    -t quay.io/freedomben/metals-tini:0.1.0 \
    -t quay.io/freedomben/metals-tini:0.1 \
    -t docker.io/freedomben/metals-tini:0.1.0 \
    -t docker.io/freedomben/metals-tini:0.1 \
    -f Dockerfile.tini \
    .

  $PODMAN tag \
    quay.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:0.1.0 \
    quay.io/freedomben/metals:0.1.0

  $PODMAN tag \
    quay.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:0.1.0 \
    quay.io/freedomben/metals:0.1

  $PODMAN tag \
    docker.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:0.1.0 \
    docker.io/freedomben/metals:0.1.0

  $PODMAN tag \
    docker.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:0.1.0 \
    docker.io/freedomben/metals:0.1
}

main "$@"
