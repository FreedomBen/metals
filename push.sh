#!/usr/bin/env bash

set -e

. scripts/common.sh

main ()
{
  local current_version
  local short_version
  current_version="$(check_extract_version)"
  short_version="$(parse_short_version "$current_version")"

  # Push the images up
  push_image "quay.io/freedomben/metals:${current_version}"
  push_image "quay.io/freedomben/metals:${short_version}"
  push_image "docker.io/freedomben/metals:${current_version}"
  push_image "docker.io/freedomben/metals:${short_version}"

  for image in "nginx-116" "nginx-114" "nginx-117" "tini"; do
    push_image "quay.io/freedomben/metals-${image}:${current_version}"
    push_image "quay.io/freedomben/metals-${image}:${short_version}"
    push_image "docker.io/freedomben/metals-${image}:${current_version}"
    push_image "docker.io/freedomben/metals-${image}:${short_version}"
  done
}

main "$@"
