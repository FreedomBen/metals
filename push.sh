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

  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals:0.1.0
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals:0.1
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals:0.1.0
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals:0.1

  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-nginx-116:0.1.0
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-nginx-116:0.1
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-nginx-116:0.1.0
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-nginx-116:0.1

  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-nginx-114:0.1.0
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-nginx-114:0.1
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-nginx-114:0.1.0
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-nginx-114:0.1

  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-nginx-117:0.1.0
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-nginx-117:0.1
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-nginx-117:0.1.0
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-nginx-117:0.1

  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-tini:0.1.0
  $PODMAN push --authfile ~/.docker/config.json quay.io/freedomben/metals-tini:0.1
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-tini:0.1.0
  $PODMAN push --authfile ~/.docker/config.json docker.io/freedomben/metals-tini:0.1
}

main "$@"
