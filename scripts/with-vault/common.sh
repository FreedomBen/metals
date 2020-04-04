
# This file should be sourced from the others

export PODMAN=
#PODMAN="sudo $(command -v podman) --authfile ~/.docker/config.json"
PODMAN="sudo $(command -v podman)"

export VAULT_IMAGE='docker.io/vault:1.3.2'
export METALS_IMAGE='docker.io/freedomben/metals:latest'
export METALS_EXAMPLE_IMAGE="docker.io/freedomben/metals-example" # Expected to exist locally (you can use build.sh in the root dir to build this)

export VAULT_CONTAINER='vault'
export METALS_CONTAINER='mtls'
export METALS_EXAMPLE_CONTAINER='metals-example'

export PODNAME=metals-example-pod
export PODFILE="${PODNAME}.yaml"

export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=sjxPvVLhl8Q5PS3yUPQdEJkLd
export VAULT_NAMESPACE=

die ()
{
  echo "[DIE]: $1"
}

