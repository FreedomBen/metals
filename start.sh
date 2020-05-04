#!/usr/bin/env bash
# shellcheck disable=SC2091

#set -x
set -e
set -o pipefail

declare -r NGINX_ACCESS_LOG_FILE="/var/log/nginx/access.log"
declare -r NGINX_ERROR_LOG_FILE="/var/log/nginx/error.log"

# Array needs to be a global variable so functions can add to it
declare -a nginx_health_check_location_blocks_text=()

die ()
{
  echo "[FATAL]: start.sh: $1"
  if [ -n "$SLEEP_ON_FATAL" ]; then
    echo "Sleeping for '${SLEEP_ON_FATAL}' seconds because SLEEP_ON_FATAL is set"
    sleep "${SLEEP_ON_FATAL}"
  fi
  exit 1
}

debug ()
{
  if [[ "$METALS_DEBUG" =~ ([Tt]rue|[Yy]es) ]]; then
    echo -e "[DEBUG]: start.sh: $1" >&2
  fi
}

debug_unsafe ()
{
  if [[ "$METALS_DEBUG_UNSAFE" =~ ([Tt]rue|[Yy]es) ]]; then
    echo -e "[DEBUG_UNSAFE]: start.sh: $1" >&2
  fi
}

warn ()
{
  echo "[WARN]: start.sh $1" >&2
}

info ()
{
  echo "[INFO]: start.sh: $1" >&2
}

nginx_config_file_location ()
{
  if [ -n "$METALS_NGINX_CONFIG_FILE_LOCATION" ]; then
    echo "$METALS_NGINX_CONFIG_FILE_LOCATION"
  elif [ -d "/etc/nginx/conf.d" ]; then
    echo "/etc/nginx/conf.d"
  elif [ -d "/opt/app-root/etc/nginx.d" ]; then
    echo "/opt/app-root/etc/nginx.d"
  else
    die 'Could not find suitable location for nginx config file. Please set variable METALS_NGINX_CONFIG_FILE_LOCATION and try again'
  fi
}

fail_if_env_var_missing ()
{
  debug "Checking if env var '${1}' is missing"
  if [ -z "$1" ]; then
    die "Startup script error: Must pass string with env var to check"
  elif ! $(env | grep "$1" >/dev/null 2>&1); then
    die "Required env var '${1}' is missing"
  fi
}

fail_if_all_env_vars_missing ()
{
  debug "Checking that at least env var '${1}' or '${2}' is present"
  if [ -z "$1" ] || [ -z "$1" ]; then
    die "Startup script error: Must pass two strings with env var to check"
  elif ! $(env | grep "$1" >/dev/null 2>&1) && ! $(env | grep "$2" >/dev/null 2>&1); then
    die "Required env var '${1}' or '${2}' is missing.  Please set one of them.  See README.md for more details"
  fi
}

fail_if_first_present_but_not_second ()
{
  debug "Checking that if env var '${1}' is present, so is '${2}'"
  if $(env | grep "$1" >/dev/null 2>&1) && ! $(env | grep "$2" >/dev/null 2>&1); then
    die "'$1' is present but '$2' is not.  See README.md for more details"
  fi
}

first_or_second_present ()
{
  env | grep "$2" >/dev/null 2>&1 || env | grep "$3" >/dev/null 2>&1
}

fail_if_first_present_but_not_second_or_third ()
{
  debug "Checking that if env var '${1}' is present, so is '${2}' or '${3}'"
  if $(env | grep "$1" >/dev/null 2>&1) && ! $(first_or_second_present "$2" "$3"); then
    die "'$1' is present but '$2' or '$3' is not.  See README.md for more details"
  fi
}

check_required_vault_env_vars ()
{
  # If the private key isn't provided already, make sure we
  # have a vault addr and path to retrieve one with
  if [ -z "${METALS_PRIVATE_KEY}" ]; then
    info "Private key is not in METALS_PRIVATE_KEY. Requiring VAULT_ADDR and either VAULT_TOKEN or VAULT_ROLE"

    fail_if_env_var_missing "VAULT_ADDR"

    fail_if_all_env_vars_missing \
      "VAULT_TOKEN" \
      "VAULT_ROLE"
  else
    debug "Private key is in METALS_PRIVATE_KEY. Using that"
  fi
}

check_required_env_vars ()
{
  debug "Checking that required env vars are present"

  check_required_vault_env_vars

  fail_if_all_env_vars_missing \
    "METALS_PRIVATE_KEY" \
    "METALS_PRIVATE_KEY_VAULT_KEY"
  fail_if_all_env_vars_missing \
    "METALS_PUBLIC_CERT" \
    "METALS_PUBLIC_CERT_VAULT_KEY"
  fail_if_all_env_vars_missing \
    "METALS_SERVER_TRUST_CHAIN" \
    "METALS_SERVER_TRUST_CHAIN_VAULT_KEY"
  fail_if_all_env_vars_missing \
    "METALS_CLIENT_TRUST_CHAIN" \
    "METALS_CLIENT_TRUST_CHAIN_VAULT_KEY"

  fail_if_first_present_but_not_second \
    "VAULT_ROLE" \
    "VAULT_KUBERNETES_AUTH_PATH"

  fail_if_first_present_but_not_second_or_third \
    "METALS_PRIVATE_KEY_VAULT_KEY" \
    "METALS_PRIVATE_KEY_VAULT_PATH" \
    "METALS_VAULT_PATH"
  fail_if_first_present_but_not_second_or_third \
    "METALS_PUBLIC_CERT_VAULT_KEY" \
    "METALS_PUBLIC_CERT_VAULT_PATH" \
    "METALS_VAULT_PATH"
  fail_if_first_present_but_not_second_or_third \
    "METALS_SERVER_TRUST_CHAIN_VAULT_KEY" \
    "METALS_SERVER_TRUST_CHAIN_VAULT_PATH" \
    "METALS_VAULT_PATH"
  fail_if_first_present_but_not_second_or_third \
    "METALS_CLIENT_TRUST_CHAIN_VAULT_KEY" \
    "METALS_CLIENT_TRUST_CHAIN_VAULT_PATH" \
    "METALS_VAULT_PATH"
}

warn_or_die_on_ssl ()
{
  # If SSL is disabled then we can proceed without valid certs,
  # Meaning we do not need to exit.  If SSL is enabled then we
  # need to fail rather than risk starting with a bad key/cert
  if [ "${METALS_TLS_ENABLED}" = "off" ]; then
    warn "$1"
  else
    die "$1"
  fi
}

curl_vault_secret ()
{
  # shellcheck disable=SC2086
  curl \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" \
    -H "X-Vault-Request: true" \
    -H "X-Vault-Namespace: ${VAULT_NAMESPACE}" \
    -X GET \
    "$(vault_full_endpoint $1)"
}

vault_full_endpoint ()
{
  echo "$(sanitized_vault_addr)/v1/$(sanitized_vault_path "${1}")"
}

retrieve_vault_secret ()
{
  info "Retrieving secret from vault path '${1}' (Associated key '${2}')"
  local curl_result

  # Temporarily turn off -e so we can handle a curl error
  # on our own (otherwise bash will exit)
  set +e
  # shellcheck disable=2086
  curl_result="$(curl_vault_secret ${1})"
  curl_retval="$?"
  set -e

  # If this is a public cert, and debug is enabled, print out
  # the whole curl_result to make troubleshooting easier
  # Use a whitelist approach to avoid any accidental leakage of secrets
  debug_unsafe "\$curl_result from vault path '${1}' key '${2}' is: '${curl_result}'"

  if [ "$curl_retval" = "0" ]; then
    # shellcheck disable=SC2155
    local err_msg_supp="Error retrieving secret for vault path '${1}' (Associated key '${2}').  Full Vault URL: '$(vault_full_endpoint "$1")'.  Result: '${curl_result}'"
    if $(echo "$curl_result" | grep 'permission.denied' >/dev/null 2>&1); then
      warn_or_die_on_ssl "Permission denied by Vault.  Check your Vault token.  ${err_msg_supp}"
    elif $(echo "$curl_result" | grep '\{\s*"errors"\s*:\s*\[\s*\]\s*\}' >/dev/null 2>&1); then
      warn_or_die_on_ssl "Vault returned an empty error array from the API.  This probably means the Vault Path '${1}' does not exist.  ${err_msg_supp}"
    elif $(echo "$curl_result" | grep '^."errors"' >/dev/null 2>&1); then
      warn_or_die_on_ssl "Vault returned errors from the API.  ${err_msg_supp}"
    else
      info "Retrieved secret from vault path '${1}'. Have not yet parsed it for key '${2}'.  Full Vault URL: '$(vault_full_endpoint "$1")'"
    fi
  else
    warn_or_die_on_ssl "Error retrieving secret for vault path '${1}' (Associated key '${2}').  Full Vault URL: '$(vault_full_endpoint "$1")'.  Result: '${curl_result}'"
  fi

  # If jq is installed, use that for parsing Vault's response. Otherwise use ruby
  if command -v jq >/dev/null 2>&1; then
    parse_and_write_vault_json_response_jq "$1" "$2" "$3" "${curl_result}"
  elif command -v ruby >/dev/null 2>&1; then
    parse_and_write_vault_json_response_ruby "$1" "$2" "$3" "${curl_result}"
  else
    warn_or_die_on_ssl "Neither jq nore ruby is installed. One of them is required to parse the JSON response from Vault.  Please add it to the image and try again"
  fi
}

parse_and_write_vault_json_response_jq ()
{
  # $1=path $2=key $3=filename $4=curl_result
  # Write curl result to file specified in $3
  if echo "${4}" | jq -r ".data.${2}" > "$3"; then
    info "Successfully parsed json key '${2}' from secret from vault path '${1}' (using jq)"
  else
    warn_or_die_on_ssl "Error parsing json key '${2}' from secret for vault path '${1}' (using jq)"
  fi
}

parse_and_write_vault_json_response_ruby ()
{
  # $1=path $2=key $3=filename $4=curl_result
  if echo "${4}" \
     | ruby -r json -e "puts JSON.parse(STDIN.read)['data']['$2']" \
     > "$3"
  then
    info "Successfully parsed json key '${2}' from secret from vault path '${1}' (using ruby)"
  else
    warn_or_die_on_ssl "Error parsing json key '${2}' from secret for vault path '${1}' (using ruby)"
  fi
}

sanitized_vault_path ()
{
  echo "${1}" \
    | sed -e 's|^/||g' \
    | sed -e 's|/$||g' \
    | sed -e 's|//|/|g'
}

first_or_second ()
{
  if [ -n "$1" ]; then
    echo "$1"
  else
    echo "$2"
  fi
}

write_ssl_certificate ()
{
  if [ -n "$METALS_PUBLIC_CERT" ]; then
    debug 'Using SSL certificate literal from env var'
    printf '%s\n' "$METALS_PUBLIC_CERT" > "$1"
  else
    debug 'Retrieving SSL certificate from Vault'

    local path
    path="$(first_or_second \
      "$METALS_PUBLIC_CERT_VAULT_PATH" \
      "$METALS_VAULT_PATH" \
    )"
    local key=$METALS_PUBLIC_CERT_VAULT_KEY
    retrieve_vault_secret "${path}" "${key}" "$1"
  fi
}

write_ssl_certificate_key ()
{
  if [ -n "$METALS_PRIVATE_KEY" ]; then
    debug 'Using SSL certificate key literal from env var'
    printf '%s\n' "$METALS_PRIVATE_KEY" > "$1"
  else
    debug 'Retrieving SSL certificate key from Vault'

    local path
    path="$(first_or_second \
      "$METALS_PRIVATE_KEY_VAULT_PATH" \
      "$METALS_VAULT_PATH" \
    )"
    local key=$METALS_PRIVATE_KEY_VAULT_KEY
    retrieve_vault_secret "${path}" "${key}" "$1"
  fi
}

write_ssl_client_certificate ()
{
  if [ -n "$METALS_CLIENT_TRUST_CHAIN" ]; then
    debug 'Using SSL client certificate literal from env var'
    printf '%s\n' "$METALS_CLIENT_TRUST_CHAIN" > "$1"
  else
    debug 'Retrieving SSL client certificate from Vault'

    local path
    path="$(first_or_second \
      "$METALS_CLIENT_TRUST_CHAIN_VAULT_PATH" \
      "$METALS_VAULT_PATH" \
    )"
    local key=$METALS_CLIENT_TRUST_CHAIN_VAULT_KEY
    retrieve_vault_secret "${path}" "${key}" "$1"
  fi
}

write_ssl_trusted_certificate ()
{
  if [ -n "$METALS_SERVER_TRUST_CHAIN" ]; then
    debug 'Using SSL trusted certificate literal from env var'
    printf '%s\n' "$METALS_SERVER_TRUST_CHAIN" > "$1"
  else
    debug 'Retrieving SSL trusted certificate from Vault'

    local path
    path="$(first_or_second \
      "$METALS_SERVER_TRUST_CHAIN_VAULT_PATH" \
      "$METALS_VAULT_PATH" \
    )"
    local key=$METALS_SERVER_TRUST_CHAIN_VAULT_KEY
    retrieve_vault_secret "${path}" "${key}" "$1"
  fi
}

file_not_empty ()
{
  if [ ! -s "$1" ] || ! grep -E '\S' "$1" >/dev/null 2>&1; then
    warn "File '$1' appears to be empty'"
    return 1
  else
    info "File '$1' is not empty"
    return 0
  fi
}

file_has_multiple_lines ()
{
  local MIN_NUM_LINES=3

  debug "Checking that file '$1' has at least $MIN_NUM_LINES lines"

  local num_lines
  if [ -n "$1" ] && [ -f "$1" ]; then
    num_lines="$(wc -l "$1" | awk '{ print $1 }')"
  else
    warn "File '$1' does not appear to exist!"
    return 2
  fi

  if (( num_lines >= MIN_NUM_LINES )); then
    debug "File '$1' has $num_lines lines, which is more than the minimum of '$MIN_NUM_LINES'"
    return 0
  else
    warn "File '$1' has only $num_lines lines, which is less than the minimum of '$MIN_NUM_LINES'"
    return 1
  fi
}

file_header_is_pem ()
{
  debug "Checking that file '$1' header is valid PEM"

  if [ -n "$1" ] && [ -f "$1" ] && head -1 "$1" | grep '^-----BEGIN' >/dev/null 2>&1; then
    debug "File '$1' has $(wc -l "$1") lines, which is more than the minimum of '$MIN_NUM_LINES'"
    return 0
  else
    warn "File '$1' header is not valid PEM.  It does not start with '-----BEGIN'"
    return 1
  fi
}

file_is_pem ()
{
  debug "Checking that file '$1' is a valid PEM file"
  if [ -n "$1" ] && [ -f "$1" ] && file_has_multiple_lines "$1" && file_header_is_pem "$1"; then
    info "File '$1' appears to be valid PEM'"
    return 0
  else
    warn "File '$1' is not valid PEM.  It either doesn't exist, has too few lines, or doesn't have a valid PEM header"
    return 1
  fi
}

file_not_null ()
{
  debug "Checking that file '${1}' is not null"
  if grep '^null' "${1}"; then
    warn_or_die_on_ssl "File '${1}' was null, but should not be.  The JSON key was not found in the JSON blob, and is likely incorrect"
  fi
}

valid_pem_file ()
{
  # Prefer $1 if it exists and has a valid certificate or key
  # $2 is the file to fall back to if $1 fails validation
  debug "Checking that file '$1' is valid"
  if file_not_empty "$1" && file_not_null "$1" && file_is_pem "$1" && ! file_is_encrypted_pem "$1"; then
    info "File '$1' appears to be valid'"
    echo "$1"
  else
    warn "File '$1' is not valid/readable PEM.  Falling back to default certificate"
    echo "$2"
  fi
}

build_nginx_health_check_location_blocks ()
{
  for location in $METALS_SKIP_CLIENT_AUTH_PATH $METALS_SKIP_CLIENT_AUTH_PATH_0 $METALS_SKIP_CLIENT_AUTH_PATH_1 $METALS_SKIP_CLIENT_AUTH_PATH_2 $METALS_SKIP_CLIENT_AUTH_PATH_3 $METALS_HEALTH_CHECK_PATH $METALS_HEALTH_CHECK_PATH_0 $METALS_HEALTH_CHECK_PATH_1 $METALS_HEALTH_CHECK_PATH_2 $METALS_HEALTH_CHECK_PATH_3
  do
    nginx_health_check_location_blocks_text+=("
        location ~ ${location} {
          $(nginx_location_block)
        }
    ")
  done
}

nginx_location_block ()
{
  cat <<- EOF
            # It is preferrable to use 127.0.0.1 rather than
            # localhost because it avoids a lookup with the resolver
            proxy_pass         ${METALS_PROXY_PASS_PROTOCOL:-http}://backend;
            proxy_http_version 1.1;                 # required for keepalive
            proxy_set_header   Connection       ""; # Remove close header for keepalive
            proxy_set_header  X-Real-IP        \$remote_addr;
            proxy_set_header  X-Forwarded-For  \$proxy_add_x_forwarded_for;
            proxy_set_header  X-Client-Dn      \$ssl_client_s_dn;
            proxy_set_header  Host             \$http_host;
            proxy_redirect    off;
EOF
}

listen_ssl ()
{
  if [ "$MTLS_SSL" = 'off' ]; then
    echo ''
  else
    echo 'ssl'
  fi
}

nginx_server_block ()
{
  # $5 = verify_client
  # $6 = listen port
  cat <<- EOF
        listen       ${6:-"8443"} default_server $(listen_ssl);
        listen       [::]:${6:-"8443"} default_server $(listen_ssl);
        server_name  ${METALS_SERVER_NAME:-"_"};
        root         /usr/share/nginx;

        ssl_certificate_key     $(valid_pem_file "$1" "/mtls/default-certificates/server.key");
        ssl_certificate         $(valid_pem_file "$2" "/mtls/default-certificates/server.crt");
        ssl_trusted_certificate $(valid_pem_file "$3" "/mtls/default-certificates/rootca.crt");
        ssl_client_certificate  $(valid_pem_file "$4" "/mtls/default-certificates/rootca.crt");
        ssl_verify_depth        ${METALS_TLS_VERIFY_DEPTH:-"5"};
        ssl_verify_client       ${5:-"on"};
        ssl_session_timeout     ${METALS_TLS_SESSION_TIMEOUT:-"5m"};
        ssl_protocols  ${METALS_TLS_PROTOCOLS:-"TLSv1.2 TLSv1.3"};
        ssl_ciphers  ${METALS_TLS_CIPHERS:-"HIGH:!aNULL:!MD5"};
        ssl_prefer_server_ciphers   on;

        #resolver $(awk '/^nameserver/{print $2}' /etc/resolv.conf | tr '\n' ' ') valid=30s;
        resolver 127.0.0.11 valid=30s;
EOF
}

nginx_health_check_location_blocks ()
{
  build_nginx_health_check_location_blocks
  echo "${nginx_health_check_location_blocks_text[*]}"
}

# Old nginx.conf for reference (can remove this once it is
# working and tested with health checks
generate_nginx_config_no_health_checks ()
{
  debug 'Generating and writing nginx config file'

  mkdir -p "$(nginx_config_file_location)"

  local nginx_config_file
  nginx_config_file="$(nginx_config_file_location)/mtls.conf"
  cat <<- EOF > "$nginx_config_file"
    server {
        listen       ${METALS_LISTEN_PORT:-"8443"} default_server;
        listen       [::]:${METALS_LISTEN_PORT:-"8443"} default_server;
        server_name  ${METALS_SERVER_NAME:-"_"};
        root         /usr/share/nginx/html;
        ssl                     ${METALS_TLS_ENABLED:-"on"};
        ssl_certificate_key     $(valid_pem_file "$1" "/mtls/default-certificates/server.key");
        ssl_certificate         $(valid_pem_file "$2" "/mtls/default-certificates/server.crt");
        ssl_trusted_certificate $(valid_pem_file "$3" "/mtls/default-certificates/rootca.crt");
        ssl_client_certificate  $(valid_pem_file "$4" "/mtls/default-certificates/rootca.crt");
        ssl_verify_depth        ${METALS_TLS_VERIFY_DEPTH:-"5"};
        ssl_verify_client       ${METALS_TLS_VERIFY_CLIENT:-"on"};
        ssl_session_timeout     ${METALS_TLS_SESSION_TIMEOUT:-"5m"};
        ssl_protocols  ${METALS_TLS_PROTOCOLS:-"TLSv1.2 TLSv1.3"};
        ssl_ciphers  ${METALS_TLS_CIPHERS:-"HIGH:!aNULL:!MD5"};
        ssl_prefer_server_ciphers   on;

        #resolver 127.0.0.11 valid=30s;
        resolver $(awk '/^nameserver/{print $2}' /etc/resolv.conf | tr '\n' ' ') valid=30s;

        location / {
            proxy_pass         ${METALS_PROXY_PASS_PROTOCOL:-http}://backend;
            proxy_http_version 1.1;                 # required for keepalive
            proxy_set_header   Connection       ""; # Remove close header for keepalive
            proxy_set_header   X-Real-IP        \$remote_addr;
            proxy_set_header   X-Forwarded-For  \$proxy_add_x_forwarded_for;
            proxy_set_header   X-Client-Dn      \$ssl_client_s_dn;
            proxy_set_header   Host             \$http_host;
            proxy_redirect     off;
        }
    }
EOF
  info "Wrote nginx config file to '${nginx_config_file}'.  Start file:"
  chmod 0640 "$nginx_config_file"
  debug 'Successfully chmodded nginx config file to 0640'
  info "Contents of ${nginx_config_file} file:"
  cat "$nginx_config_file"
  info "End nginx config file"
}

keepalive_timeout ()
{
  # keepalive_timeout was introduced in nginx 1.15
  # so don't use it on nginx 1.14
  if [ "${NGINX_VERSION}" = '1.14' ]; then
    echo "# keepalive_timeout not available until nginx 1.15"
  else
    echo "keepalive_timeout ${METALS_UPSTREAM_KEEPALIVE_TIMEOUT:-60s};"
  fi
}

generate_nginx_config ()
{
  # $1 thru $4 are cert files, $5 is verify client
  debug 'Generating and writing nginx config file'

  mkdir -p "$(nginx_config_file_location)"

  local nginx_config_file
  nginx_config_file="$(nginx_config_file_location)/mtls.conf"
  cat <<- EOF > "$nginx_config_file"
    # Upstream definition
    upstream backend {
        # It is preferrable to use 127.0.0.1 rather than
        # localhost because it avoids a lookup with the resolver
        server              ${METALS_PROXY_PASS_HOST:-127.0.0.1}:${METALS_FORWARD_PORT:-8080} weight=1;
        keepalive           ${METALS_UPSTREAM_KEEPALIVE_CONNECTIONS:-32};
        $(keepalive_timeout)
    }

    # Health check server (no client auth required)
    server {
        $(nginx_server_block "$1" "$2" "$3" "$4" "off" "${METALS_SKIP_CLIENT_AUTH_LISTEN_PORT:-9443}")

        $(nginx_health_check_location_blocks)
    }

    # Main block for proxy (requires client auth)
    server {
        $(nginx_server_block "$1" "$2" "$3" "$4" "${METALS_TLS_VERIFY_CLIENT:-'on'}" "${METALS_LISTEN_PORT:-8443}")

        location / {
            $(nginx_location_block)
        }
    }
EOF
  info "Wrote nginx config file to '${nginx_config_file}'.  Start file:"
  chmod 0640 "$nginx_config_file"
  debug 'Successfully chmodded nginx config file to 0640'
  info "Contents of ${nginx_config_file} file:"
  cat "$nginx_config_file"
  info "End nginx config file"
}

check_not_null ()
{
  debug "Checking that file '${1}' is not null"
  if grep '^null' "${1}"; then
    warn_or_die_on_ssl "File '${1}' was null, but should not be.  The JSON key is likely incorrect"
  fi
}

check_is_pem ()
{
  debug "Checking that file '${1}' is valid PEM format"
  if ! file_is_pem "$1"; then
    warn_or_die_on_ssl "File '${1}' is not a valid PEM file"
  fi
}

check_is_not_encrypted_pem ()
{
  debug "Checking that file '${1}' is not encrypted PEM"
  if file_is_encrypted_pem "$1"; then
    warn_or_die_on_ssl "File '${1}' is an encrypted PEM.  Nginx cannot use an encrypted file without prompting for the passphrase, which cannot be done remotely.  You need to decrypt the file and try again.  If you exported this file from a keystore tool, make sure it is being exported in plaintext (not encrypted)."
  fi
}

file_is_encrypted_pem ()
{
  debug "Checking that file '$1' is not encrypted PEM"

  if [ -n "$1" ] && [ -f "$1" ] && head -1 "$1" | grep 'ENCRYPTED' >/dev/null 2>&1; then
    debug "File '$1' does not have ENCRYPTED in the PEM header, so is not encrypted"
    return 0
  else
    warn "File '$1' appears to be encrypted PEM.  It contains 'ENCRYPTED' in the header.  You need to decrypt the file and try again."
    return 1
  fi
}

sanity_check_cert_files ()
{
  for file in "$@"; do
    debug "Performing sanity check on cert file '$file'"
    check_not_null "$file"
    check_is_pem "$file"
    check_is_not_encrypted_pem "$file"
  done
}

symlink_log_files ()
{
  # If files are already symlinked (like in nginx official docker image)
  # Remove them because of the nginx permission issue (selinux related)
  #if [ -h "${NGINX_ACCESS_LOG_FILE}" ]; then
  #  rm "${NGINX_ACCESS_LOG_FILE}"
  #  rm "${NGINX_ERROR_LOG_FILE}"
  #fi

  # Create the log files if they don't exist
  touch "${NGINX_ACCESS_LOG_FILE}"
  touch "${NGINX_ERROR_LOG_FILE}"

  # Until we get the permission issue with nginx opening
  # stdout and stderr as non-root user, no point in symlinking
  #ln -sf /dev/stdout "${NGINX_ACCESS_LOG_FILE}"
  #ln -sf /dev/stderr "${NGINX_ERROR_LOG_FILE}"
}

start_nginx ()
{
  info "Starting nginx as user '$(whoami)' with 'nginx -g 'daemon off;'"
  nginx -g 'daemon off;'
}

check_trace ()
{
  if [[ "$METALS_TRACE" =~ ([Tt]rue|[Yy]es) ]]; then
    debug "METALS_TRACE is '$METALS_TRACE' so enabling firehose output"
    set -x
  fi
}

check_proxy_pass_host ()
{
  if [ "$METALS_PROXY_PASS_HOST" != '127.0.0.1' ]; then
    warn "You have METALS_PROXY_PASS_HOST set to '${METALS_PROXY_PASS_HOST}' which is not currently supported due to https://github.com/FreedomBen/metals/issues/1"
  fi
}

fail_if_not_valid_vault_path ()
{
  if ! [ "$1" = "" ] && ! [[ $1 =~ [A-Za-z0-9/]+ ]]; then
    die "'$1' is not a valid vault path"
  fi
}

check_valid_vault_paths ()
{
  fail_if_not_valid_vault_path "$METALS_PRIVATE_KEY_VAULT_PATH"
  fail_if_not_valid_vault_path "$METALS_PUBLIC_CERT_VAULT_PATH"
  fail_if_not_valid_vault_path "$METALS_SERVER_TRUST_CHAIN_VAULT_PATH"
  fail_if_not_valid_vault_path "$METALS_CLIENT_TRUST_CHAIN_VAULT_PATH"
}

check_valid_vault_url ()
{
  if [ -n "$VAULT_ADDR" ] && ! [[ $VAULT_ADDR =~ https?://[A-Za-z0-9/]+ ]]; then
    die "VAULT_ADDR value doesn't look valid. Failed regex check"
  fi
}

check_valid_serviceaccount_token ()
{
  if [ -z "$METALS_PRIVATE_KEY" ] && [ -z "$VAULT_TOKEN" ] && ! [ -f "$KUBERNETES_SERVICE_ACCOUNT_TOKEN_FILE" ]; then
    warn_or_die_on_ssl "METALS_PRIVATE_KEY is empty, and VAULT_TOKEN is not set, but the Kubernetes service account token is missing.  Expected it to be in the file '${KUBERNETES_SERVICE_ACCOUNT_TOKEN_FILE}'"
  fi
}

check_valid_vault_kubernetes_auth_path ()
{
  # If there's no private key litera, and no VAULT_TOKEN, then we need a valid root path
  if [ -z "$METALS_PRIVATE_KEY" ] && [ -z "$VAULT_TOKEN" ] && ! [[ $VAULT_KUBERNETES_AUTH_PATH =~ [A-Za-z0-9/]+/login$ ]]; then
    die "VAULT_TOKEN is empty, and VAULT_KUBERNETES_AUTH_PATH doesn't look valid. Failed regex check.  It should end with '/login'"
  fi
}

sanitized_vault_addr ()
{
  # shellcheck disable=SC2001
  echo "$VAULT_ADDR" \
    | sed -e 's|/$||g'
}

sanitized_vault_kube_auth_path ()
{
  echo "$VAULT_KUBERNETES_AUTH_PATH" \
    | sed -e 's|^/||g' \
    | sed -e 's|/$||g' \
    | sed -e 's|//|/|g' \
    | sed -e 's|^v1/||g'
}

vault_kube_auth_full_endpoint ()
{
  echo "$(sanitized_vault_addr)/v1/$(sanitized_vault_kube_auth_path)"
}

curl_kube_auth ()
{
  JWT="$(cat "$KUBERNETES_SERVICE_ACCOUNT_TOKEN_FILE")"
  curl \
    --request POST \
    --data "{\"role\":\"${VAULT_ROLE}\",\"jwt\":\"${JWT}\"}" \
    "$(vault_kube_auth_full_endpoint)"
}

parse_and_save_vault_client_token_json_response_jq ()
{
  # Parse client token and store in VAULT_TOKEN
  if echo "${1}" | jq -r '.auth.client_token' >/dev/null 2>&1; then
    # shellcheck disable=SC2155
    export VAULT_TOKEN="$(echo "${1}" | jq -r '.auth.client_token')"
    info 'Successfully parsed client token from Vault login using jq'
  else
    warn_or_die_on_ssl "Error parsing client_token from Vault response using jq.  JSON response: '${1}'"
  fi
}

parse_and_save_vault_client_token_json_response_ruby ()
{
  # Parse client token and store in VAULT_TOKEN
  if echo "${1}" \
     | ruby -r json -e "puts JSON.parse(STDIN.read)['auth']['client_token']" >/dev/null 2>&1
  then
    # shellcheck disable=SC2155
    export VAULT_TOKEN="$(echo "${1}" \
      | ruby -r json -e "puts JSON.parse(STDIN.read)['auth']['client_token']")"
    info 'Successfully parsed client token from Vault login using ruby'
  else
    warn_or_die_on_ssl "Error parsing client_token from Vault response using ruby.  JSON response: '${1}'"
  fi
}

retrieve_vault_token ()
{
  # If VAULT_TOKEN is empty, populate it
  debug 'Checking if VAULT_TOKEN is empty, meaning we need to retrieve it from Vault using the serviceaccount token'
  if [ -n "$VAULT_TOKEN" ]; then
    info "VAULT_TOKEN is already set.  Will use that instead of retrieving client token from Vault kube auth"
  else
    info "VAULT_TOKEN not set.  Retrieving client token from vault using kubernetes service account"
    local curl_result

    # Temporarily turn off -e so we can handle a curl error
    # on our own (otherwise bash will exit)
    set +e
    # shellcheck disable=2086
    curl_result="$(curl_kube_auth)"
    curl_retval="$?"
    set -e

    if [ "$curl_retval" = "0" ]; then
      if $(echo "$curl_result" | grep '^."errors"' >/dev/null 2>&1); then
        warn_or_die_on_ssl "Vault returned errors from the API.  Error retrieving client token with serviceaccount.  Full Vault URL: '$(vault_kube_auth_full_endpoint)'.  Result: '${curl_result}'"
      else
        info "Retrieved client token secret from vault.  Full Vault URL: '$(vault_kube_auth_full_endpoint)'"
      fi
    else
      warn_or_die_on_ssl "Error retrieving client token using serviceaccount for vault.  Full Vault URL: '$(vault_kube_auth_full_endpoint)'.  Result: '${curl_result}'"
    fi

    # If jq is installed, use that for parsing Vault's response. Otherwise use ruby
    if command -v jq >/dev/null 2>&1; then
      parse_and_save_vault_client_token_json_response_jq "${curl_result}"
    elif command -v ruby >/dev/null 2>&1; then
      parse_and_save_vault_client_token_json_response_ruby "${curl_result}"
    else
      warn_or_die_on_ssl "Neither jq nore ruby is installed. One of them is required to parse the JSON response from Vault.  Please add it to the image and try again"
    fi

    if [ -z "$VAULT_TOKEN" ]; then
      warn_or_die_on_ssl 'VAULT_TOKEN is still empty string after receiving and parsing'
    fi
  fi
}

main ()
{
  check_trace

  check_required_env_vars
  check_proxy_pass_host
  check_valid_vault_paths
  check_valid_vault_url
  check_valid_serviceaccount_token
  check_valid_vault_kubernetes_auth_path

  # If VAULT_TOKEN is empty and we don't have a private key literal,
  # this will populate retrieve the VAULT_TOKEN from Vault with service account JWT
  if [ -z "$METALS_PRIVATE_KEY" ] && [ -z "$VAULT_TOKEN" ]; then
    retrieve_vault_token
    fail_if_env_var_missing "VAULT_TOKEN"
  fi

  local ssl_root_dir="/var/run/ssl"
  mkdir -p $ssl_root_dir

  local ssl_certificate_key="${ssl_root_dir}/ssl_certificate.key"
  local ssl_certificate="${ssl_root_dir}/ssl_certificate.crt"
  local ssl_trusted_certificate="${ssl_root_dir}/trustchain.cer"
  local ssl_client_certificate="${ssl_root_dir}/client-trustchain.cer"

  write_ssl_certificate_key     "$ssl_certificate_key"
  write_ssl_certificate         "$ssl_certificate"
  write_ssl_trusted_certificate "$ssl_trusted_certificate"
  write_ssl_client_certificate  "$ssl_client_certificate"

  chmod 0640 "$ssl_certificate_key"
  chmod 0644 "$ssl_certificate"
  chmod 0644 "$ssl_trusted_certificate"
  chmod 0644 "$ssl_client_certificate"

  generate_nginx_config \
    "$ssl_certificate_key" \
    "$ssl_certificate" \
    "$ssl_trusted_certificate" \
    "$ssl_client_certificate" \
    "$METALS_TLS_VERIFY_CLIENT" \
    "$METALS_SKIP_CLIENT_AUTH_LISTEN_PORT" \

#  generate_nginx_config_no_health_checks \
#    "$ssl_certificate_key" \
#    "$ssl_certificate" \
#    "$ssl_trusted_certificate" \
#    "$ssl_client_certificate" \

  symlink_log_files

  sanity_check_cert_files \
    "$ssl_certificate_key" \
    "$ssl_certificate" \
    "$ssl_trusted_certificate" \
    "$ssl_client_certificate"

  # There is an issue where nginx can't open stdout and stderr
  # When it is not started as root user.  But, OpenShift uses random
  # user IDs.  To compensate for that, for now just tail the files
  # in the background
  tail -f /var/log/nginx/error.log &
  tail -f /var/log/nginx/access.log &

  start_nginx
}

main "$@"
