#!/usr/bin/env bash

function log {

   if [ "$LOG" == "true" ]; then

      printf "$@" | tee -a "$LOG_FILE"
   fi
}
