#!/usr/bin/env bash

function log {

   if [[ "$log" == "true" ]]; then

      dt=$(date '+%d.%m.%y %H:%M:%S');
      printf "${name}:${dt}: $@" | tee -a "${log_file}"
   fi
}