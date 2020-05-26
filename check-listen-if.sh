#!/usr/bin/env bash

# When using MeTaLS in a side car, you do not want your
# application to listen on 0.0.0.0 as it can allow others
# to bypass authentication/authorization.  This script will
# use the downward API to attempt to detect an application
# that is listening on 000.0 0.0.0.0 rather than 127.0.0.1 and
# print a warning message

set -e
set -o pipefail

die ()
{
  echo "[FATAL]: check-listen-if.sh: '$(date)': $1"
  echo '[FATAL]: Log rotate is exitings.  Logs will not be rotated!'
  exit 1
}

debug ()
{
  if [[ "$METALS_DEBUG" =~ ([Tt]rue|[Yy]es) ]]; then
    echo -e "[DEBUG]: check-listen-if.sh: '$(date)': $1" >&2
  fi
}

debug_unsafe ()
{
  if [[ "$METALS_DEBUG_UNSAFE" =~ ([Tt]rue|[Yy]es) ]]; then
    echo -e "[DEBUG_UNSAFE]: check-listen-if.sh: '$(date)': $1" >&2
  fi
}

warn ()
{
  echo -e "[WARN]: check-listen-if.sh: '$(date)': $1" >&2
}

info ()
{
  echo -e "[INFO]: check-listen-if.sh: '$(date)': $1" >&2
}

app_not_accessible ()
{
  local response
  response="$(curl "${METALS_PROXY_PASS_PROTOCOL:-http}://${1}:${METALS_FORWARD_PORT:-8080}" 2>&1)"
  #echo "Response: ${response}"
  echo "$response" | grep -i "Connection refused" >/dev/null
}

check_binding_addr ()
{
  if app_not_accessible "$POD_IP_ADDRESS"; then
    info "Application does not appear to be bound to the external interface (this is good)"
  else
    warn "

    ***************************************************************************
    *
    *   The backend application may be bound to the external interface!!!
    *   Please double check that the application is binding to 127.0.0.1
    *   rather than 0.0.0.0.  If it is binding correctly and this warning
    *   is erroneous, you can silence it by setting the environment variable
    *   METALS_BIND_CHECK_DISABLED=on
    *
    ***************************************************************************

    "
  fi
}

get_pod_ip ()
{
  if [ -n "$POD_IP_ADDRESS" ]; then
    debug "Pod IP address is set to '$POD_IP_ADDRESS' through the Downward API.  Using that"
    echo "$POD_IP_ADDRESS"
  else
    debug "Pod IP address is not set. Using hostname -l to retrive"
    local retval
    retval="$(hostname -i)"
    if [[ $retval = ^[0-9.]+$ ]]; then
      debug "Pod IP retrived with hostname -l as '$retval'"
      echo "$retval"
    else
      info "Pod IP could not be reliably determined. Will not check interface binding"
      echo ""
    fi
  fi
}

check_binding ()
{
  debug "Checking binding..."

  local pod_ip
  pod_ip="$(get_pod_ip)"

  if [ -n "$pod_ip" ]; then
    check_binding_addr "$pod_ip"
  else
    warn "Pod IP address is not available.  Cannot verify that application is bound to 127.0.0.1 rather than 0.0.0.0 (if the application binds to the external interface, it can create a backdoor for callers to bypass authentication/authorization provided by MeTaLS"
  fi
}

main ()
{
  if [ "$METALS_BIND_CHECK_DISABLED" != "on" ]; then
    local bind_check_delay="${METALS_BIND_CHECK_DELAY_SECONDS:-60}"

    debug "Waiting $bind_check_delay seconds for application to initialize before checking that application is not bound to 0.0.0.0"
    sleep "$bind_check_delay"

    info "Checking that application is not externally bound (0.0.0.0)"
    check_binding
  else
    debug "Bind check is disabled.  Not checking"
  fi
}

main "$@"
