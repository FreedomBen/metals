# shellcheck disable=SC2155

# This file should be sourced from the others

export PODMAN=
#PODMAN="sudo $(command -v podman) --authfile ~/.docker/config.json"
PODMAN="sudo $(command -v podman)"

export METALS_IMAGE='docker.io/freedomben/metals:latest'
export METALS_EXAMPLE_IMAGE="docker.io/freedomben/metals-example" # Expected to exist locally (you can use build.sh in the root dir to build this)

export METALS_CONTAINER='metals'
export METALS_EXAMPLE_CONTAINER='metals-example'

export PODNAME=metals-example-pod
export PODFILE="${PODNAME}.yaml"

export CERTS=certs
if [ -d scripts/certs ]; then
  CERTS=scripts/certs
fi

if ! [ -d "$CERTS" ]; then
  echo "Can't find certs dir. Run from root of project"
  exit 1
fi

if [ -z "$TARGET_HOST" ]; then
  export TARGET_HOST=localhost:8443
fi

if [ -z "$HEALTH_CHECK_TARGET_HOST" ]; then
  export HEALTH_CHECK_TARGET_HOST=localhost:9443
fi

export CERT_DIR="$CERTS/simple-root-client-server"
export UNTRUSTED_CERT_DIR="$CERTS/valid-but-untrusted-root-intermediate"

export SERVER_KEY_FILE="$CERT_DIR/server.key"
export SERVER_CERT_FILE="$CERT_DIR/server.crt"
export CLIENT_KEY_FILE="$CERT_DIR/server.key"
export CLIENT_CERT_FILE="$CERT_DIR/server.crt"
export TRUST_CHAIN_FILE="$CERT_DIR/rootca.crt"

file_to_env_var ()
{
  # This shellcheck is wrong in this case.  Without using
  # cat first and piping to awk it breaks
  # shellcheck disable=SC2002
  #cat "$1" | awk '{printf "%s\\n", $0}'
  cat "$1"
}

export SERVER_PUBLIC_CERT="$(file_to_env_var "$SERVER_CERT_FILE")"
export SERVER_PRIVATE_KEY="$(file_to_env_var "$SERVER_KEY_FILE")"
export TRUST_CHAIN="$(file_to_env_var "$TRUST_CHAIN_FILE")"

die ()
{
  echo "[DIE]: $1"
}

create_pod ()
{
  echo "Creating pod..."
  $PODMAN pod create \
    --name "$PODNAME" \
    -p 8080:8080 \
    -p 8200:8200 \
    -p 8443:8443 \
    -p 9443:9443
  echo "Done creating pod"
}

shell_metals_example ()
{
  echo 'Implement me!'
}

exec_metals_example ()
{
  $PODMAN exec -it "$METALS_EXAMPLE_CONTAINER" bash
}

start_metals_example ()
{
  echo "starting example service..."
  $PODMAN run \
    --detach \
    --pod "$PODNAME" \
    --name "$METALS_EXAMPLE_CONTAINER" \
    "$METALS_EXAMPLE_IMAGE"
  echo "Done starting example service"
}

exec_metals ()
{
  $PODMAN exec -it "$METALS_CONTAINER" bash
}

shell_metals ()
{
  start_metals "bash"
}

start_metals ()
{
  local det_or_it
  if [ -n "$1" ]; then
    det_or_it='-it'
  else
    det_or_it='--detach'
  fi

  echo "Starting metals..."
  # double quote on the $1 below breaks the script because
  # we don't want this to count as an arg unless it's populated
  # shellcheck disable=SC2086
  $PODMAN run \
    $det_or_it \
    --user 12345 \
    \
    --env METALS_SSL=on \
    --env METALS_SSL_VERIFY_CLIENT=on \
    --env METALS_DEBUG=true \
    \
    --env METALS_PROXY_PASS_PROTOCOL=http \
    --env METALS_PROXY_PASS_HOST=127.0.0.1 \
    --env METALS_FORWARD_PORT=8080 \
    \
    --env METALS_PUBLIC_CERT="${SERVER_PUBLIC_CERT}" \
    --env METALS_PRIVATE_KEY="${SERVER_PRIVATE_KEY}" \
    --env METALS_SERVER_TRUST_CHAIN="${TRUST_CHAIN}" \
    --env METALS_CLIENT_TRUST_CHAIN="${TRUST_CHAIN}" \
    \
    --env METALS_HEALTH_CHECK_PATH=/health \
    \
    --name "$METALS_CONTAINER" \
    --pod "$PODNAME" \
    "$METALS_IMAGE" \
    $1  
  echo "Done starting metals"
}

import_pod ()
{
  $PODMAN play kube "$PODFILE"
}

export_pod ()
{
  $PODMAN generate kube "$PODNAME" > "$PODFILE"
}

stop_metals ()
{
  $PODMAN stop "$METALS_CONTAINER"
  $PODMAN rm "$METALS_CONTAINER"
}

stop_metals_example ()
{
  $PODMAN stop "$METALS_EXAMPLE_CONTAINER"
  $PODMAN rm "$METALS_EXAMPLE_CONTAINER"
}

remove_pod ()
{
  $PODMAN pod rm -f "$PODNAME"
}

client_request ()
{
  echo "Kicking off client request with valid client cert to TARGET_HOST '$TARGET_HOST'"
  curl -v \
    --cacert ./$TRUST_CHAIN_FILE \
    --key ./$CLIENT_KEY_FILE \
    --cert ./$CLIENT_CERT_FILE \
    https://$TARGET_HOST/testing/mtls/long/path?querystring=thisvalue
}

badauth_client_request ()
{
  # Has certs but they aren't authorized
  echo "Kicking off client request with BAD client cert to TARGET_HOST '$TARGET_HOST'"
  curl -v \
    --cacert ./$TRUST_CHAIN_FILE \
    --key ./$UNTRUSTED_CERT_DIR/client.key \
    --cert ./$UNTRUSTED_CERT_DIR/client.crt \
    https://${TARGET_HOST}/testing/mtls/long/path?querystring=thisvalue
}

health_client_request ()
{
  echo "Kicking off health check client request with NO client cert to TARGET_HOST '$TARGET_HOST'"
  curl -v \
    --cacert ./$TRUST_CHAIN_FILE \
    https://$HEALTH_CHECK_TARGET_HOST/health?Healthy=1
}

plaintext_request ()
{
  echo "Kicking off http client request with NO client cert to TARGET_HOST '$TARGET_HOST'"
  curl -v \
    --insecure \
    http://${TARGET_HOST}/testing/mtls/long/path?querystring=thisvalue
}

unauthed_client_request ()
{
  echo "Kicking off client request with NO client cert to TARGET_HOST '$TARGET_HOST'"
  curl -v \
    --cacert ./$TRUST_CHAIN_FILE \
    https://${TARGET_HOST}/testing/mtls/long/path?querystring=thisvalue
}

header_client_request ()
{
  echo "Kicking off client request with extra headers and valid client cert to TARGET_HOST '$TARGET_HOST'"
  curl -v \
    --cacert ./$TRUST_CHAIN_FILE \
    --key ./$CLIENT_KEY_FILE \
    --cert ./$CLIENT_CERT_FILE \
    -H 'X-Client-Dn: hacked.xyz' \
    -H 'X-Hello-World: word' \
    https://$TARGET_HOST/testing/mtls/long/path?querystring=thisvalue
}
