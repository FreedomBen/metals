#!/usr/bin/env bash

set -e

. scripts/common.sh

main ()
{
  local current_version
  local short_version
  current_version="$(check_extract_version)"
  short_version="$(parse_short_version "$current_version")"

  pull_and_build_dockerfile "nginx-116" "$current_version" "$short_version"
  pull_and_build_dockerfile "nginx-114" "$current_version" "$short_version"
  pull_and_build_dockerfile "nginx-117" "$current_version" "$short_version"
  pull_and_build_dockerfile "tini" "$current_version" "$short_version"

  echo -e "\033[1;36mTagging 'metals-nginx-${DEFAULT_RELEASE}' as metals'"

  $PODMAN tag \
    "quay.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:${current_version}" \
    "quay.io/freedomben/metals:${current_version}"

  $PODMAN tag \
    "quay.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:${short_version}" \
    "quay.io/freedomben/metals:${short_version}"

  $PODMAN tag \
    "docker.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:${current_version}" \
    "docker.io/freedomben/metals:${current_version}"

  $PODMAN tag \
    "docker.io/freedomben/metals-nginx-${DEFAULT_RELEASE}:${short_version}" \
    "docker.io/freedomben/metals:${short_version}"
}

main "$@"
