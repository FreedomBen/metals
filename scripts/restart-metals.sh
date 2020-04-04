#!/usr/bin/env bash

if [ -d scripts ]; then
  ./scripts/stop-mtls.sh
  ./scripts/start-mtls.sh
else
  ./stop-mtls.sh
  ./start-mtls.sh
fi
