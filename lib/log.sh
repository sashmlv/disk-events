#!/usr/bin/env bash

function log {

   if [[ "$log" == "true" ]]; then

      printf "${name}: $@" | tee -a "${log_file}"
   fi
}