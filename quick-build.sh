#!/usr/bin/env bash

set -e

PODMAN="sudo podman"

die ()
{
  echo "[DIE]: $1"
}

main ()
{
  local nginx_ver="116"
  [ -n "$1" ] && nginx_ver="$1"
  local image_suffix="nginx-"
  [ "$1" = "tini" ] && image_suffix=""

  $PODMAN build \
    -t "quay.io/freedomben/metals-${image_suffix}${nginx_ver}:latest" \
    -t "quay.io/freedomben/metals-${image_suffix}${nginx_ver}:1.0" \
    -t "docker.io/freedomben/metals-${image_suffix}${nginx_ver}:latest" \
    -t "docker.io/freedomben/metals-${image_suffix}${nginx_ver}:1.0" \
    -f "Dockerfile.${image_suffix}${nginx_ver}" \
    .

  $PODMAN tag \
    "quay.io/freedomben/metals-${image_suffix}${nginx_ver}:latest" \
    "quay.io/freedomben/metals:latest"

  $PODMAN tag \
    "docker.io/freedomben/metals-${image_suffix}${nginx_ver}:latest" \
    "docker.io/freedomben/metals:latest"
}

main "$@"
