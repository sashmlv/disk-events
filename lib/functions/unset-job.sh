#!/usr/bin/env bash

function unset_job {

   print_jobs

   if [[ "${#ids[@]}" -eq 0 ]]; then

      printf 'Nothing to remove'
      exit
   fi

   id=
   while [[ -z "${id}" ]]; do

      printf 'Enter record id: '
      read id
   done

   # check access
   touch "${jobs_file}" 2> /dev/null || {

      printf "Can't write job file, permission denied: %s\n" "${jobs_file}"
      exit
   }
   touch "${service_file}" 2> /dev/null || {

      printf "Can't write service file, permission denied: %s\n" "${service_file}"
      exit
   }

   record_found=false
   label="${labels[$id]}"
   label_escaped=$(echo "${label}" | xargs -r -d '\n' systemd-escape | sed 's/\\x/\\\\x/g')
   label_found=false
   new_ids=() # remove id from ids
   for idx in "${ids[@]}"; do

      [[ "${idx}" != "${id}" ]] && new_ids+=("${idx}")
   done
   ids=("${new_ids[@]}")
   unset new_ids
   unset 'labels[$id]'

   # try find job like this label
   for idx in "${ids[@]}"; do

      if [ "${labels[$idx]}" == "${label}" ]; then

         label_found=true
      fi
   done

   # if label not found remove from systemd
   if [[ "${label_found}" == "false" ]]; then

      mount=$(grep -m1 -oP "[^=]+${label_escaped}\.mount$" "${service_file}" || true)
      mount_point=$(echo "${mount}" | sed 's/\.mount$//' | xargs -r -d '\n' systemd-escape -u )

      if [[ ! -z "${mount}" ]] && [[ ! -z "${mount_point}" ]]; then

         # remove unwanted lines
         content=()
         while IFS= read -r line; do

            if [[ "${line}" == *"${mount}" ]]; then

               record_found=true
               continue
            fi

            if [[ "${line}" == *"${mount_point}" ]]; then

               record_found=true
               continue
            fi

            content+=("${line}")

         done < "${service_file}"

         if [[ "${#ids[@]}" -eq 0 ]]; then

            # remove service file if no jobs
            systemctl stop "${name}.service"
            systemctl disable "${name}.service"
            systemctl daemon-reload
            rm -f "${service_file}"
         else

            # update service file
            printf "%s\n" "${content[@]}" > "${service_file}"
            systemctl daemon-reload
         fi
      fi
   fi

   if grep -qP "^<${id}>" "$jobs_file"; then record_found=true; fi

   sed "/^<${id}>/d" "${jobs_file}" > "${tmp_file}"
   mv -f "${tmp_file}" "${jobs_file}"

   if [[ "${record_found}" == "true" ]]; then

      printf 'Record with id: %s removed\n' "${id}"
   else

      printf 'Record with id: %s not found\n' "${id}"
   fi
}