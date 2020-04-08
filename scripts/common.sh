# shellcheck disable=SC2155

# This file should be sourced from the others

export PODMAN=
#PODMAN="sudo $(command -v podman) --authfile ~/.docker/config.json"
PODMAN="sudo $(command -v podman)"
PODMAN_AUTHFILE="$HOME/.docker/config.json"

export DEFAULT_DOCKERFILE='Dockerfile.nginx-116'
export DEFAULT_RELEASE='116'

export VAULT_IMAGE='docker.io/vault:1.3.2'
export METALS_IMAGE='docker.io/freedomben/metals-nginx-116:latest'
export METALS_EXAMPLE_IMAGE="docker.io/freedomben/metals-example"

export METALS_CONTAINER='metals'
export METALS_EXAMPLE_CONTAINER='metals-example'
export VAULT_CONTAINER='vault'

export PODNAME='metals-example-pod'
export PODFILE="${PODNAME}.yaml"

export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN_T='sjxPvVLhl8Q5PS3yUPQdEJkLd'
export VAULT_NAMESPACE=


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

# Building an pushing functions
extract_version ()
{
  awk '/^ENV METALS_VERSION/ { print $3 }' "$1"
}

check_extract_version ()
{
  cur_ver="$(extract_version "$DEFAULT_DOCKERFILE")"

  # Check every Dockerfile to make sure versions are the same
  for dockerfile in Dockerfile.*; do
    vers=$(extract_version "$dockerfile")
    if [ "$vers" != "$cur_ver" ]; then
      die "The Dockerfile at $dockerfile has a different version than $DEFAULT_DOCKERFILE!  $DEFAULT_DOCKERFILE has version '$cur_ver' but $dockerfile has version '$vers'.  If you are releasing a new version make sure to update all the Dockerfiles"
    fi
  done

  echo "$cur_ver"
}

parse_short_version ()
{
  echo "$1" | sed -E -e 's/\.[0-9]$//g'
}

build_dockerfile ()
{
  echo -e "\033[1;36mBuilding 'Dockerfile.${1}' for version '${2}', short version '${3}'\033[0m"

  $PODMAN build \
    -t "quay.io/freedomben/metals-${1}:${2}" \
    -t "quay.io/freedomben/metals-${1}:${3}" \
    -t "docker.io/freedomben/metals-${1}:${2}" \
    -t "docker.io/freedomben/metals-${1}:${3}" \
    -f "Dockerfile.${1}" \
    .
}

push_image ()
{
  echo -e "\033[1;36mPushing image '${1}'\033[0m"

  $PODMAN push --authfile "${PODMAN_AUTHFILE}" "${1}"
}

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
  echo "[DIE]: $1" >&2
  exit 1
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
    --env METALS_DEBUG_UNSAFE=false \
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

start_metals_vault ()
{
  local det_or_it
  if [ -n "$1" ]; then
    det_or_it='-it'
  else
    det_or_it='--detach'
  fi

  echo "Starting metals with vault support..."
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
    --env METALS_DEBUG_UNSAFE=false \
    \
    --env METALS_PROXY_PASS_PROTOCOL=http \
    --env METALS_PROXY_PASS_HOST=127.0.0.1 \
    --env METALS_FORWARD_PORT=8080 \
    \
    --env VAULT_ADDR="${VAULT_ADDR}" \
    --env VAULT_TOKEN="${VAULT_TOKEN_T}" \
    \
    --env METALS_VAULT_PATH="secret/data/metals/service" \
    \
    --env METALS_PUBLIC_CERT_VAULT_KEY="data.server_crt" \
    --env METALS_PRIVATE_KEY_VAULT_KEY="data.server_key" \
    --env METALS_SERVER_TRUST_CHAIN_VAULT_KEY="data.rootca_crt" \
    --env METALS_CLIENT_TRUST_CHAIN_VAULT_KEY="data.rootca_crt" \
    \
    --env METALS_HEALTH_CHECK_PATH=/health \
    \
    --name "$METALS_CONTAINER" \
    --pod "$PODNAME" \
    "$METALS_IMAGE" \
    $1
  echo "Done starting metals"
}

start_metals_vault_diff_paths ()
{
  local det_or_it
  if [ -n "$1" ]; then
    det_or_it='-it'
  else
    det_or_it='--detach'
  fi

  echo "Starting metals with vault support..."
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
    --env METALS_DEBUG_UNSAFE=false \
    \
    --env METALS_PROXY_PASS_PROTOCOL=http \
    --env METALS_PROXY_PASS_HOST=127.0.0.1 \
    --env METALS_FORWARD_PORT=8080 \
    \
    --env VAULT_ADDR="${VAULT_ADDR}" \
    --env VAULT_TOKEN="${VAULT_TOKEN_T}" \
    \
    --env METALS_PUBLIC_CERT_VAULT_PATH="secret/data/metals/server" \
    --env METALS_PRIVATE_PATH_VAULT_PATH="secret/data/metals/server" \
    --env METALS_SERVER_TRUST_CHAIN_VAULT_PATH="secret/data/metals/rootca" \
    --env METALS_CLIENT_TRUST_CHAIN_VAULT_PATH="secret/data/metals/rootca" \
    \
    --env METALS_PUBLIC_CERT_VAULT_KEY="data.crt" \
    --env METALS_PRIVATE_KEY_VAULT_KEY="data.key" \
    --env METALS_SERVER_TRUST_CHAIN_VAULT_KEY="data.crt" \
    --env METALS_CLIENT_TRUST_CHAIN_VAULT_KEY="data.crt" \
    \
    --env METALS_HEALTH_CHECK_PATH=/health \
    \
    --name "$METALS_CONTAINER" \
    --pod "$PODNAME" \
    "$METALS_IMAGE" \
    $1
  echo "Done starting metals"
}

start_vault ()
{
  echo "Starting Vault..."
  $PODMAN run \
    --cap-add IPC_LOCK \
    --detach \
    --pod "$PODNAME" \
    --env "VAULT_DEV_ROOT_TOKEN_ID=${VAULT_TOKEN_T}" \
    --name "$VAULT_CONTAINER" \
    "$VAULT_IMAGE"
  echo "Done starting vault"
}

write_path_key_same_path ()
{
  curl \
    -H "X-Vault-Token: ${VAULT_TOKEN_T}" \
    -H "X-Vault-Request: true" \
    -H "X-Vault-Namespace: " \
    -H "Content-Type: application/json" \
    -X POST \
    --data "{
              \"data\": {
                \"${2}\": \"${3}\",
                \"${4}\": \"${5}\",
                \"${6}\": \"${7}\",
                \"${8}\": \"${9}\",
                \"${10}\": \"${11}\",
                \"${12}\": \"${13}\"
              }
            }" \
    "${VAULT_ADDR}/v1/secret/data/$1"
}

write_path_key_different_path ()
{
  curl \
    -H "X-Vault-Token: ${VAULT_TOKEN_T}" \
    -H "X-Vault-Request: true" \
    -H "X-Vault-Namespace: " \
    -H "Content-Type: application/json" \
    -X POST \
    --data "{
              \"data\": {
                \"$2\": \"$3\",
                \"$4\": \"$5\"
              }
            }" \
    "${VAULT_ADDR}/v1/secret/data/$1"
}

file_to_env_var_vault_write ()
{
  awk '{printf "%s\\n", $0}' "$1"
}

write_keys_to_vault_different_path ()
{
  local CLIENT_KEY="$(file_to_env_var_vault_write "$CLIENT_KEY_FILE")"
  local CLIENT_CRT="$(file_to_env_var_vault_write "$CLIENT_CERT_FILE")"

  local SERVER_KEY="$(file_to_env_var_vault_write "$SERVER_KEY_FILE")"
  local SERVER_CRT="$(file_to_env_var_vault_write "$SERVER_CERT_FILE")"

  local ROOT_CA_KEY="$(file_to_env_var_vault_write "$TRUST_CHAIN_FILE")"
  local ROOT_CA_CRT="$(file_to_env_var_vault_write "$TRUST_CHAIN_FILE")"

  write_path_key_different_path "metals/client" \
    "key" "$CLIENT_KEY" \
    "crt" "$CLIENT_CRT"

  write_path_key_different_path "metals/server" \
    "key" "$SERVER_KEY" \
    "crt" "$SERVER_CRT"

  write_path_key_different_path "metals/rootca" \
    "key" "$ROOT_CA_KEY" \
    "crt" "$ROOT_CA_CRT"
}

write_keys_to_vault_same_path ()
{
  local CLIENT_KEY="$(file_to_env_var_vault_write "$CLIENT_KEY_FILE")"
  local CLIENT_CRT="$(file_to_env_var_vault_write "$CLIENT_CERT_FILE")"

  local SERVER_KEY="$(file_to_env_var_vault_write "$SERVER_KEY_FILE")"
  local SERVER_CRT="$(file_to_env_var_vault_write "$SERVER_CERT_FILE")"

  local ROOT_CA_KEY="$(file_to_env_var_vault_write "$TRUST_CHAIN_FILE")"
  local ROOT_CA_CRT="$(file_to_env_var_vault_write "$TRUST_CHAIN_FILE")"

  write_path_key_same_path "metals/service" \
    "client_key" "$CLIENT_KEY" \
    "client_crt" "$CLIENT_CRT" \
    "server_key" "$SERVER_KEY" \
    "server_crt" "$SERVER_CRT" \
    "rootca_key" "$ROOT_CA_KEY" \
    "rootca_crt" "$ROOT_CA_CRT"
}

get_path_key ()
{
  local retval
  retval=$(curl \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: ${VAULT_TOKEN_T}" \
    -H "X-Vault-Request: true" \
    -H "X-Vault-Namespace: " \
    -X GET \
    "http://localhost:8200/v1/secret/data/${1}")
  echo "$retval"
  if echo "$retval" | grep '..errors' >/dev/null 2>&1; then
    echo "$retval"
  else
    #echo "$retval" | jq -r ".[\"data\"][\"${2}\"]"
    echo "$retval" | jq -r ".data.${2}"
  fi
  echo
}

read_keys_from_vault_same_path ()
{
  get_path_key "metals/service" "data.client_key"
  get_path_key "metals/service" "data.client_crt"
  get_path_key "metals/service" "data.server_key"
  get_path_key "metals/service" "data.server_crt"

  get_path_key "metals/service" "data.rootca_key"
  get_path_key "metals/service" "data.rootca_crt"
}

read_keys_from_vault_different_path ()
{
  get_path_key "metals/client" "data.key"
  get_path_key "metals/client" "data.crt"
  get_path_key "metals/server" "data.key"
  get_path_key "metals/server" "data.crt"

  get_path_key "metals/rootca" "data.key"
  get_path_key "metals/rootca" "data.crt"
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

stop_vault ()
{
  $PODMAN stop "$VAULT_CONTAINER"
  $PODMAN rm "$VAULT_CONTAINER"
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
