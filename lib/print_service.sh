#!/usr/bin/env bash

function print_service {

   if [[ ! -f "$service_file" ]]; then

      printf "Service file not found: %s\n" "$service_file"
      exit
   fi
   cat "$service_file"
}
