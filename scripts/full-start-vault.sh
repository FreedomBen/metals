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

main ()
{
  create_pod
  start_vault

  sleep 3
  write_keys_to_vault_same_path
  write_keys_to_vault_different_path

  start_metals_example

  #start_metals
  start_metals_vault
  #start_metals_vault_diff_paths
}

main "$@"
