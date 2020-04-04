#!/usr/bin/env bash
# shellcheck disable=SC2091

#set -x
set -e
set -o pipefail

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

check_required_env_vars ()
{
  debug "Checking that required env vars are present"

  fail_if_env_var_missing "METALS_PRIVATE_KEY"
  fail_if_env_var_missing "METALS_PUBLIC_CERT"
  fail_if_env_var_missing "METALS_SERVER_TRUST_CHAIN"
  fail_if_env_var_missing "METALS_CLIENT_TRUST_CHAIN"
}

warn_or_die_on_ssl ()
{
  # If SSL is disabled then we can proceed without valid certs,
  # Meaning we do not need to exit.  IF SSL is enabled then we
  # need to fail rather than risk starting with a bad key/cert
  if [ "${METALS_SSL}" = "off" ]; then
    warn "$1"
  else
    die "$1"
  fi
}

write_ssl_certificate_key ()
{
  debug 'Using SSL certificate key literal from env var'
  printf '%s\n' "$METALS_PRIVATE_KEY" > "$1"
}

write_ssl_certificate ()
{
  debug 'Using SSL certificate literal from env var'
  printf '%s\n' "$METALS_PUBLIC_CERT" > "$1"
}

write_ssl_trusted_certificate ()
{
  debug 'Using SSL trusted certificate literal from env var'
  printf '%s\n' "$METALS_SERVER_TRUST_CHAIN" > "$1"
}

write_ssl_client_certificate ()
{
  debug 'Using SSL client certificate literal from env var'
  printf '%s\n' "$METALS_CLIENT_TRUST_CHAIN" > "$1"
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

  debug "Verifying that file '$1' has at least $MIN_NUM_LINES lines"

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
  debug "Verifying that file '$1' header is valid PEM"

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
  debug "Verifying that file '$1' is a valid PEM file"
  if [ -n "$1" ] && [ -f "$1" ] && file_has_multiple_lines "$1" && file_header_is_pem "$1"; then
    info "File '$1' appears to be valid PEM'"
    return 0
  else
    warn "File '$1' is not valid PEM.  It either doesn't exist, has too few lines, or doesn't have a valid PEM header"
    return 1
  fi
}

valid_pem_file ()
{
  # Prefer $1 if it exists and has a valid certificate or key
  # $2 is the file to fall back to if $1 fails validation
  debug "Verifying that file '$1' is valid"
  if file_not_empty "$1" && file_is_pem "$1"; then
    info "File '$1' appears to be valid'"
    echo "$1"
  else
    warn "File '$1' is not valid PEM.  Falling back to default certificate"
    echo "$2"
  fi
}

build_nginx_health_check_location_blocks ()
{
  for location in $METALS_SKIP_CLIENT_AUTH_PATH $METALS_SKIP_CLIENT_AUTH_PATH_0 $METALS_SKIP_CLIENT_AUTH_PATH_1 $METALS_SKIP_CLIENT_AUTH_PATH_2 $METALS_SKIP_CLIENT_AUTH_PATH_3 $METALS_HEALTH_CHECK_PATH $METALS_HEALTH_CHECK_PATH_0 $METALS_HEALTH_CHECK_PATH_1 $METALS_HEALTH_CHECK_PATH_2 $METALS_HEALTH_CHECK_PATH_3
  do
    nginx_health_check_location_blocks_text+=("
        location ${location} {
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
            set \$upstream ${METALS_PROXY_PASS_PROTOCOL:-http}://${METALS_PROXY_PASS_HOST:-127.0.0.1}:${METALS_FORWARD_PORT:-8080};

            proxy_pass        \$upstream;
            proxy_set_header  X-Real-IP        \$remote_addr;
            proxy_set_header  X-Forwarded-For  \$proxy_add_x_forwarded_for;
            proxy_set_header  X-Client-Dn      \$ssl_client_s_dn;
            proxy_set_header  Host             \$http_host;
            proxy_redirect    off;
EOF
}

nginx_server_block ()
{
  # $5 = verify_client
  # $6 = listen port
  cat <<- EOF
        listen       ${6:-"8443"} default_server;
        listen       [::]:${6:-"8443"} default_server;
        server_name  ${METALS_SERVER_NAME:-"_"};
        #root         /opt/app-root/src;
        ssl                     ${METALS_SSL:-"on"};
        ssl_certificate_key     $(valid_pem_file "$1" "/mtls/default-certificates/server.key");
        ssl_certificate         $(valid_pem_file "$2" "/mtls/default-certificates/server.crt");
        ssl_trusted_certificate $(valid_pem_file "$3" "/mtls/default-certificates/rootca.crt");
        ssl_client_certificate  $(valid_pem_file "$4" "/mtls/default-certificates/rootca.crt");
        ssl_verify_depth        ${METALS_SSL_VERIFY_DEPTH:-"5"};
        ssl_verify_client       ${5:-"on"};
        ssl_session_timeout     ${METALS_SSL_SESSION_TIMEOUT:-"5m"};
        ssl_protocols  ${METALS_SSL_PROTOCOLS:-"TLSv1.2 TLSv1.3"};
        ssl_ciphers  ${METALS_SSL_CIPHERS:-"HIGH:!aNULL:!MD5"};
        ssl_prefer_server_ciphers   on;

        #resolver 127.0.0.11 valid=30s;
        resolver $(awk '/^nameserver/{print $2}' /etc/resolv.conf | tr '\n' ' ') valid=30s;
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
        root         /opt/app-root/src;
        ssl                     ${METALS_SSL:-"on"};
        ssl_certificate_key     $(valid_pem_file "$1" "/mtls/default-certificates/server.key");
        ssl_certificate         $(valid_pem_file "$2" "/mtls/default-certificates/server.crt");
        ssl_trusted_certificate $(valid_pem_file "$3" "/mtls/default-certificates/rootca.crt");
        ssl_client_certificate  $(valid_pem_file "$4" "/mtls/default-certificates/rootca.crt");
        ssl_verify_depth        ${METALS_SSL_VERIFY_DEPTH:-"5"};
        ssl_verify_client       ${METALS_SSL_VERIFY_CLIENT:-"on"};
        ssl_session_timeout     ${METALS_SSL_SESSION_TIMEOUT:-"5m"};
        ssl_protocols  ${METALS_SSL_PROTOCOLS:-"TLSv1.2 TLSv1.3"};
        ssl_ciphers  ${METALS_SSL_CIPHERS:-"HIGH:!aNULL:!MD5"};
        ssl_prefer_server_ciphers   on;

        #resolver 127.0.0.11 valid=30s;
        resolver $(awk '/^nameserver/{print $2}' /etc/resolv.conf | tr '\n' ' ') valid=30s;

        location / {
            # It is preferrable to use 127.0.0.1 rather than
            # localhost because it avoids a lookup with the resolver
            set \$upstream ${METALS_PROXY_PASS_PROTOCOL:-http}://${METALS_PROXY_PASS_HOST:-127.0.0.1}:${METALS_FORWARD_PORT:-8080};

            proxy_pass        \$upstream;
            proxy_set_header  X-Real-IP        \$remote_addr;
            proxy_set_header  X-Forwarded-For  \$proxy_add_x_forwarded_for;
            proxy_set_header  X-Client-Dn      \$ssl_client_s_dn;
            proxy_set_header  Host             \$http_host;
            proxy_redirect    off;
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

generate_nginx_config ()
{
  # $1 thru $4 are cert files, $5 is verify client
  debug 'Generating and writing nginx config file'

  mkdir -p "$(nginx_config_file_location)"

  local nginx_config_file
  nginx_config_file="$(nginx_config_file_location)/mtls.conf"
  cat <<- EOF > "$nginx_config_file"
    # Health check server (no client auth required)
    server {
      $(nginx_server_block "$1" "$2" "$3" "$4" "off" "${METALS_HEALTH_CHECK_LISTEN_PORT:-9443}")

      $(nginx_health_check_location_blocks)
    }

    # Main block for proxy (requires client auth)
    server {
      $(nginx_server_block "$1" "$2" "$3" "$4" "${METALS_SSL_VERIFY_CLIENT:-'on'}" "${METALS_LISTEN_PORT:-8443}")

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
    warn_or_die_on_ssl "File '${1}' was null, but should not be"
  fi
}

check_is_pem ()
{
  debug "Checking that file '${1}' is valid PEM format"
  if ! file_is_pem "$1"; then
    warn_or_die_on_ssl "File '${1}' is not a valid PEM file"
  fi
}

sanity_check_cert_files ()
{
  for file in "$@"; do
    debug "Performing sanity check on cert file '$file'"
    check_not_null "$file"
    check_is_pem "$file"
  done
}

symlink_log_files ()
{
  # Create the log files if they don't exist
  touch /var/log/nginx/access.log
  touch /var/log/nginx/error.log

  # Until we get the permission issue with nginx opening
  # stdout and stderr as non-root user, no point in symlinking
  #ln -sf /dev/stdout /var/log/nginx/access.log
  #ln -sf /dev/stderr /var/log/nginx/error.log
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

main ()
{
  check_trace

  check_required_env_vars
  check_proxy_pass_host

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
    "$METALS_SSL_VERIFY_CLIENT" \
    "$METALS_HEALTH_CHECK_LISTEN_PORT" \

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
