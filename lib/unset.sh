#!/usr/bin/env bash

if [ "$cli_cmd" == 'unset' ]; then

   print_jobs # contains read_jobs

   if [[ "${#ids[@]}" -eq 0 ]]; then

      printf 'Nothing to remove'
      exit
   fi

   id=
   while [[ -z "$id" ]]; do

      printf 'Enter record id: '
      read id
   done

   # check access
   touch "$JOBS_FILE" 2> /dev/null || {

      printf "Can't write job file, permission denied: %s\n" "$JOBS_FILE"
      exit
   }
   touch "$SERVICE_FILE" 2> /dev/null || {

      printf "Can't write service file, permission denied: %s\n" "$SERVICE_FILE"
      exit
   }

   record_found=false
   label="${labels[$id]}"
   label_escaped=$(echo "${label}" | xargs -d '\n' systemd-escape | sed 's/\\x/\\\\x/g')
   label_found=false
   new_ids=() # remove id from ids
   for idx in "${ids[@]}"; do

      [[ "$idx" != "$id" ]] && new_ids+=("$idx")
   done
   ids=("${new_ids[@]}")
   unset new_ids
   unset 'labels[$id]'

   # try find job like this label
   for id in "${ids[@]}"; do

      if [ "${labels[$id]}" == "$label" ]; then

         label_found=true
      fi
   done

   # if label not found remove from systemd
   if [ "$label_found" == "false" ]; then

      mount=$(grep -m1 -oP "[^=]+${label_escaped}\.mount$" "${SERVICE_FILE}" || true)
      mount_point=$(echo "${mount}" | sed 's/\.mount$//' | xargs -d '\n' systemd-escape -u )

      if [[ ! -z "$mount" ]] && [[ ! -z "$mount_point" ]]; then

         # remove unwanted lines
         content=()
         while IFS= read -r line; do

            if [[ "${line}" == *"$mount" ]]; then

               record_found=true
               continue
            fi

            if [[ "${line}" == *"$mount_point" ]]; then

               record_found=true
               continue
            fi

            content+=("${line}")

         done < "$SERVICE_FILE"

         if [[ "${#ids[@]}" -eq 0 ]]; then

            # remove service file if no jobs
            systemctl stop "$NAME.service"
            systemctl disable "$NAME.service"
            systemctl daemon-reload
            rm -f "$SERVICE_FILE"
         else

            # update service file
            printf "%s\n" "${content[@]}" > "$SERVICE_FILE"
            systemctl daemon-reload
         fi
      fi
   fi

   if grep -qP "^<${id}>" "$JOBS_FILE"; then record_found=true; fi

   sed "/^<$id>/d" "$JOBS_FILE" > "$TMP_FILE"
   mv -f "$TMP_FILE" "$JOBS_FILE"

   if [ "$record_found" == "true" ]; then

      printf 'Record with id: %s removed\n' "$id"
   else

      printf 'Record with id: %s not found\n' "$id"
   fi
fi
