#!/usr/bin/env bash

# This is a very simple log rotation tool to keep
# volumes from filling up.  Once nginx is able to
# write directly to stdout, this can be removed.
# The primary goal here is simplicity, not integrity
# of log files.  It is possible that the split second
# between moving the old log file and truncating the
# current one could lose a line or two.

set -e
set -o pipefail

die ()
{
  echo "[FATAL]: log-rotate.sh: '$(date)': $1"
  echo '[FATAL]: Log rotate is exitings.  Logs will not be rotated!'
  exit 1
}

debug ()
{
  if [[ "$METALS_DEBUG" =~ ([Tt]rue|[Yy]es) ]]; then
    echo -e "[DEBUG]: log-rotate.sh: '$(date)': $1" >&2
  fi
}

debug_unsafe ()
{
  if [[ "$METALS_DEBUG_UNSAFE" =~ ([Tt]rue|[Yy]es) ]]; then
    echo -e "[DEBUG_UNSAFE]: log-rotate.sh: '$(date)': $1" >&2
  fi
}

warn ()
{
  echo "[WARN]: log-rotate.sh: '$(date)': $1" >&2
}

info ()
{
  echo "[INFO]: log-rotate.sh: '$(date)': $1" >&2
}

rotate_logs ()
{
  info "Rotating log files"
  cp /var/log/nginx/access.log /var/log/nginx/access.log.yesterday
  echo "Rotated at $(date)" > /var/log/nginx/access.log
  info "Rotated /var/log/nginx/access.log to /var/log/nginx/access.log.yesterday"
  cp /var/log/nginx/error.log /var/log/nginx/error.log.yesterday
  echo "Rotated at $(date)" > /var/log/nginx/error.log
  info "Rotated /var/log/nginx/error.log to /var/log/nginx/error.log.yesterday"
}

main ()
{
  local log_rotation_hours="${METALS_LOG_ROTATION_HOURS:-24}"
  local num_sleep_seconds="$((log_rotation_hours * 60 * 60))"

  info "Beginning log rotation loop.  Rotating logs every ${log_rotation_hours} hours"

  while true; do
    debug "Log rotation sleeping for $num_sleep_seconds seconds"
    sleep "$num_sleep_seconds"
    rotate_logs
  done
}

main "$@"
