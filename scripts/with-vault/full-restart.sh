#!/usr/bin/env bash

if [ -d scripts ]; then
  ./scripts/full-stops.sh
  ./scripts/full-start.sh
else
  ./full-stop.sh
  ./full-start.sh
fi
