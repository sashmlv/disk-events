#!/usr/bin/env bash

if [ "$cli_cmd" == 'unset' ]; then

   print_jobs

   printf 'Enter record id: '
   read id

   touch "$JOBS_FILE" 2> /dev/null || {
      printf "Can't write job file, permission denied: %s\n" "$JOBS_FILE"
      exit
   }
   sed "/^<$id>/d" "$JOBS_FILE" > "$TMP_FILE"
   mv -f "$TMP_FILE" "$JOBS_FILE"

   systemctl daemon-reload

   printf 'Record with id: %s removed\n' "$id"
fi
