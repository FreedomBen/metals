# shellcheck disable=SC2155

# This file should be sourced from the others
export color_light_green='\033[1;32m'
export color_light_red='\033[1;31m'
export color_light_cyan='\033[1;36m'
export color_cyan='\033[0;36m'
export color_restore='\033[0m'

export PODMAN=
#PODMAN="sudo $(command -v podman) --authfile ~/.docker/config.json"
PODMAN="sudo $(command -v podman)"
PODMAN_AUTHFILE="$HOME/.docker/config.json"

export DEFAULT_DOCKERFILE='Dockerfile.nginx-116'
export DEFAULT_RELEASE='116'

export VAULT_IMAGE='docker.io/vault:1.3.2'
export METALS_IMAGE='docker.io/freedomben/metals:latest'
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
  # Make default arg for first
  local filename="${DEFAULT_DOCKERFILE}"
  [ -n "$1" ] && filename="$1"
  awk '/^ENV METALS_VERSION/ { print $3 }' "${filename}"
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

pull_image ()
{
  echo -e "\033[1;36mPulling image '${from_image}'\033[0m"
  $PODMAN pull "${1}"
}

pull_base_image ()
{
  local from_image
  from_image="$(head -1 "Dockerfile.${1}" | awk '{ print $2 }')"
  pull_image "${from_image}"
}

build_dockerfile ()
{
  echo -e "\033[1;36mBuilding 'Dockerfile.${1}' for version '${2}', short version '${3}'\033[0m"

  $PODMAN build \
    -t "quay.io/freedomben/metals-${1}:${2}" \
    -t "quay.io/freedomben/metals-${1}:${3}" \
    -t "quay.io/freedomben/metals-${1}:latest" \
    -t "docker.io/freedomben/metals-${1}:${2}" \
    -t "docker.io/freedomben/metals-${1}:${3}" \
    -t "docker.io/freedomben/metals-${1}:latest" \
    -f "Dockerfile.${1}" \
    .
}

pull_and_build_dockerfile ()
{
  pull_base_image "${@}"
  build_dockerfile "${@}"
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
    --env "METALS_TLS_ENABLED=${2:-on}" \
    --env "METALS_TLS_VERIFY_CLIENT=${3:-on}" \
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
  # $1 is CMD to run
  # $2 is TLS enabled
  # $3 is client verify enabled
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
    --env "METALS_TLS_ENABLED=${2:-on}" \
    --env "METALS_TLS_VERIFY_CLIENT=${3:-on}" \
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
    --env METALS_TLS_ENABLED=on \
    --env METALS_TLS_VERIFY_CLIENT=on \
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
  echo -e "${color_light_cyan}Kicking off client request with valid client cert to TARGET_HOST '$TARGET_HOST'${color_restore}"
  # shellcheck disable=SC2086
  curl $1 \
    --silent \
    --cacert ./$TRUST_CHAIN_FILE \
    --key ./$CLIENT_KEY_FILE \
    --cert ./$CLIENT_CERT_FILE \
    "${2:-https}://$TARGET_HOST/testing/mtls/long/path?querystring=thisvalue"
}

badauth_client_request ()
{
  # Has certs but they aren't authorized
  echo -e "${color_light_cyan}Kicking off client request with BAD client cert to TARGET_HOST '$TARGET_HOST'${color_restore}"
  # shellcheck disable=SC2086
  curl $1 \
    --silent \
    --cacert ./$TRUST_CHAIN_FILE \
    --key ./$UNTRUSTED_CERT_DIR/client.key \
    --cert ./$UNTRUSTED_CERT_DIR/client.crt \
    "${2:-https}://${TARGET_HOST}/testing/mtls/long/path?querystring=thisvalue"
}

health_client_request ()
{
  echo -e "${color_light_cyan}Kicking off health check client request with NO client cert to TARGET_HOST '$TARGET_HOST'${color_restore}"
  # shellcheck disable=SC2086
  curl $1 \
    --silent \
    --cacert ./$TRUST_CHAIN_FILE \
    "${2:-https}://$HEALTH_CHECK_TARGET_HOST/health?Healthy=1"
}

plaintext_request ()
{
  echo -e "${color_light_cyan}Kicking off http client request with NO client cert to TARGET_HOST '$TARGET_HOST'${color_restore}"
  # shellcheck disable=SC2086
  curl $1 \
    --silent \
    --insecure \
    http://${TARGET_HOST}/testing/mtls/long/path?querystring=thisvalue
}

unauthed_client_request ()
{
  echo -e "${color_light_cyan}Kicking off client request with NO client cert to TARGET_HOST '$TARGET_HOST'${color_restore}"
  # shellcheck disable=SC2086
  curl $1 \
    --silent \
    --cacert ./$TRUST_CHAIN_FILE \
    "${2:-https}://${TARGET_HOST}/testing/mtls/long/path?querystring=thisvalue"
}

header_client_request ()
{
  echo -e "${color_light_cyan}Kicking off client request with extra headers and valid client cert to TARGET_HOST '$TARGET_HOST'${color_restore}"
  # shellcheck disable=SC2086
  curl $1 \
    --silent \
    --cacert ./$TRUST_CHAIN_FILE \
    --key ./$CLIENT_KEY_FILE \
    --cert ./$CLIENT_CERT_FILE \
    -H 'X-Client-Dn: hacked.xyz' \
    -H 'X-Hello-World: word' \
    "${2:-https}://$TARGET_HOST/testing/mtls/long/path?querystring=thisvalue"
}

full_stop ()
{
  echo -e "Stopping containers (cleanup)"
  stop_metals
  stop_metals_example
  stop_vault
  remove_pod
}

print_pass ()
{
  echo -e "${color_light_green}PASSED${color_restore}"
}

print_fail ()
{
  echo -e "${color_light_red}FAILED${color_restore} - MeTaLS response:\n\n$1"
  full_stop
  exit 1
}

check_test_result ()
{
  # $1 is dockerfile_suffix
  # $2 is name
  # $3 is response
  # $4 is grep regex
  # $5 is a log file

  echo -e "${color_light_cyan}Test result for $2 to ${1}${color_restore}" \
    | tee -a "${5:-test-results.log}"
  if echo "$3" | grep -E "$4" >/dev/null 2>&1; then
    print_pass | tee -a "${5:-test-results.log}"
  else
    print_fail "$3" | tee -a "${5:-test-results.log}"
  fi
}

# mTLS enabled (client verify enabled)
run_mtls_requests ()
{
  # $1 is dockerfile_suffix, $2 is name, $3 is response, $4 is grep regex
  check_test_result \
    "${1}" \
    "mTLS client request" \
    "$(client_request '')" \
    'GET\s.testing.mtls.long.path.*querystring.*thisvalue'

  check_test_result \
    "${1}" \
    "mTLS bad authed client request" \
    "$(badauth_client_request '')" \
    '400 The SSL certificate error'

  check_test_result \
    "${1}" \
    "mTLS health check client request" \
    "$(health_client_request '')" \
    '^Healthy$'

  check_test_result \
    "${1}" \
    "mTLS unauthenticated client request" \
    "$(unauthed_client_request '')" \
    '400 No required SSL certificate was sent'
}

# TLS enabled but client verify disabled
run_tls_requests ()
{
  # $1 is dockerfile_suffix, $2 is name, $3 is response, $4 is grep regex
  check_test_result \
    "${1}" \
    "TLS client request" \
    "$(client_request '')" \
    'GET\s.testing.mtls.long.path.*querystring.*thisvalue'

  check_test_result \
    "${1}" \
    "TLS bad authed client request" \
    "$(badauth_client_request '')" \
    'GET\s.testing.mtls.long.path.*querystring.*thisvalue'

  check_test_result \
    "${1}" \
    "TLS health check client request" \
    "$(health_client_request '')" \
    '^Healthy$'

  check_test_result \
    "${1}" \
    "TLS unauthenticated client request" \
    "$(unauthed_client_request '')" \
    'GET\s.testing.mtls.long.path.*querystring.*thisvalue'
}

# TLS disabled entirely
run_no_tls_requests ()
{
  # $1 is dockerfile_suffix, $2 is name, $3 is response, $4 is grep regex
  check_test_result \
    "${1}" \
    "No TLS client request" \
    "$(plaintext_request '')" \
    'GET\s.testing.mtls.long.path.*querystring.*thisvalue'
}

get_dockerfile_suffix ()
{
  if [ "$1" = "tini" ]; then
    echo "tini"
  else
    echo "nginx-${1}"
  fi
}

start_metals_test_env ()
{
  # $1 - nginx ver "116", $2 - "vault", $3 - tls enabled 'on', $4 - client verify enabled 'on'
  full_stop
  set -e

  local cur_ver
  local short_ver
  local dockerfile_suffix
  dockerfile_suffix="$(get_dockerfile_suffix "$1")"
  cur_ver="$(extract_version "Dockerfile.${dockerfile_suffix}")"
  short_ver="$(parse_short_version "${cur_ver}")"

  pull_and_build_dockerfile "$dockerfile_suffix" "$cur_ver" "$short_ver"

  # tag as metals:latest so it gets started by later functions
  echo -e "${color_light_cyan}Tagging metals-${dockerfile_suffix}:${cur_ver} as metals:latest${color_restore}"
  $PODMAN tag \
    "docker.io/freedomben/metals-${dockerfile_suffix}:${cur_ver}" \
    "docker.io/freedomben/metals:latest"
  $PODMAN tag \
    "quay.io/freedomben/metals-${dockerfile_suffix}:${cur_ver}" \
    "quay.io/freedomben/metals:latest"
  echo -e "${color_light_cyan}Tagging done.${color_restore}"

  create_pod
  start_metals_example

  if [ "$2" = "vault" ];then 
    start_vault
    echo -e "${color_light_cyan}Waiting 5 seconds for Vault to start${color_restore}"
    sleep 5
    echo -e "${color_light_cyan}Writing keys/certs to Vault${color_restore}"
    write_keys_to_vault_same_path
    write_keys_to_vault_different_path
    echo -e "${color_light_cyan}Starting Metals in Vault mode${color_restore}"
    start_metals_vault '' "$3" "$4"
  else
    start_metals '' "$3" "$4"
  fi

  # Give metals time to start
  echo "Waiting 5 seconds for MeTaLS to start..."
  sleep 5
  set +e
}

test_nginx ()
{
  local dockerfile_suffix
  dockerfile_suffix="$(get_dockerfile_suffix "$1")"
  test_nginx_full_mtls "$1" "$dockerfile_suffix"
  test_nginx_reg_tls "$1" "$dockerfile_suffix"
  test_nginx_no_tls "$1" "$dockerfile_suffix"
}

test_nginx_full_mtls ()
{
  # No vault, full mTLS
  echo -e "${color_light_cyan}Starting test env for Full mTLS (no vault), nginx v${1}${color_restore}"
  start_metals_test_env "$1" '' 'on' 'on'
  echo -e "${color_light_cyan}Testing Full mTLS (no vault), nginx v${1}${color_restore}"
  run_mtls_requests "$2"
  full_stop || true
}

test_nginx_reg_tls ()
{
  # Regular TLS, with vault
  echo -e "${color_light_cyan}Starting test env for regular TLS (with vault), nginx v${1}${color_restore}"
  start_metals_test_env "$1" "vault" "on" "off"
  echo -e "${color_light_cyan}Testing regular TLS (with vault), nginx v${1}${color_restore}"
  run_tls_requests "$2"
  full_stop || true
}

test_nginx_no_tls ()
{
  # No TLS, with vault
  echo -e "${color_light_cyan}Starting test env for No TLS (with no vault), nginx v${1}${color_restore}"
  start_metals_test_env "$1" "" "off" "off"
  echo -e "${color_light_cyan}Testing No TLS (with vault), nginx v${1}${color_restore}"
  run_no_tls_requests "$2"
  full_stop || true
}

test_nginx_114 ()
{
  test_nginx "114"
}

test_nginx_115 ()
{
  test_nginx "115"
}

test_nginx_116 ()
{
  test_nginx "116"
}

test_nginx_117 ()
{
  test_nginx "117"
}

test_nginx_tini ()
{
  test_nginx "tini"
}

test_nginx_all ()
{
  for vers in 114 116 117 tini; do
    test_nginx "$vers"
  done
}
