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

  # Push the images up
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals:latest
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals:1.0
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals:latest
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals:1.0

  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-dumb-init:latest
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-dumb-init:1.0
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-dumb-init:latest
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-dumb-init:1.0

  $PODMAN push quay.io/freedomben/metals-tini:latest
  $PODMAN push quay.io/freedomben/metals-tini:1.0
  $PODMAN push docker.io/freedomben/metals-tini:latest
  $PODMAN push docker.io/freedomben/metals-tini:1.0
}

main "$@"
