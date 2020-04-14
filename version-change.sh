#!/usr/bin/env bash

set -e

die ()
{
  echo "[FATAL]: $1" >&2
  exit 1
}

main ()
{
  if [ -z "$1" ] || [[ $1 =~ -?-h(elp)? ]]; then
    die 'Pass new version number as first arg. Should be SEMVER like 1.2.3'
  elif ! [[ $1 =~ ^v?[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    die 'Version number failed regex check.  Should be SEMVER like 1.2.3'
  else
    local new_version
    new_version="$(echo "$1" | sed -E -e 's/^v//g')" # strip leading v
    for f in $(
      grep -r -E 'METALS_VERSION\s[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' . \
      | awk -F : '{ print $1 }' \
      | sort \
      | uniq
    )
        do
          echo "Updating file '$f'"
          sed -i -E -e \
            "s/METALS_VERSION\s[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/METALS_VERSION ${new_version}/g" \
            "$f"
        done
  fi
}

main "$@"
