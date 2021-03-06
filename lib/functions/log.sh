#!/usr/bin/env bash

function log {

   if [[ "$logger" == "true" ]]; then

      dt=$(date '+%d.%m.%y %H:%M:%S');
      printf "${name}: ${dt}: $@" | tee -a "${log_file}"
   fi
}