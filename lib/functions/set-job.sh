#!/usr/bin/env bash

function set_job {

   declare cli_label_ok=
   declare mount_point=
   declare mount_unit=

   while [[ -z "${cli_label_ok}" ]] || [[ "${cli_label_ok}" == 'no' ]]; do

      cli_label_ok='yes'

      if [[ -z "${cli_label}" ]]; then

         cli_label_ok='no'
      fi

      if [[ "${cli_label_ok}" == 'yes' ]] && [[ $(validate 'label' "${cli_label}") == 'false' ]]; then

         cli_label_ok='no'
      fi

      if [[ "${cli_label_ok}" == 'yes' ]]; then

         mount_point=$(get_mount_point "${cli_label}")

         if [[ "${mount_point}" == 'false' ]]; then

            cli_label_ok='no'
         fi
      fi

      if [[ "${cli_label_ok}" == 'yes' ]]; then

         mount_unit=$(get_mount_unit "${cli_label}")

         if [[ "${mount_unit}" == 'false' ]]; then

            cli_label_ok='no'
         fi
      fi

      if [[ "${cli_label_ok}" == 'no' ]] || [[ -z "${cli_label}" ]]; then

         printf 'Enter disk label: '
         read cli_label
      fi
   done

   # add systemd lines
   declare conditionPathIsMountPoint="ConditionPathIsMountPoint=|$mount_point"
   declare wantedBy="WantedBy=$mount_unit"
   awk -v conditionPathIsMountPoint="$conditionPathIsMountPoint" -v wantedBy="$wantedBy" '/\[Unit\]/ { print; print conditionPathIsMountPoint; next }; /\[Install\]/ { print; print wantedBy; next }1' "$service_file" | awk '!NF || !x[$0]++' > "$tmp_file"
   mv -f "$tmp_file" "$service_file" 2> /dev/null || {
      printf "Can't write service file, permission denied: %s\n" "$service_file"
      exit
   }

   declare watch_path=

   while [[ ! -z "${cli_path}" ]]; do

      watch_path=$(get_watch_path "${mount_point}" "${cli_path}")

      if [[ ! -z "${watch_path}" && ( -d "${watch_path}" || -f "${watch_path}" ) ]]; then

         break
      else

         printf 'set_job: Path not found: %s\n' "${cli_path}"
      fi

      printf 'Enter path: '
      read cli_path
   done

   while [[ $(validate 'timeout' "${cli_timeout}" 'no-log') == 'false' ]]; do

      printf 'Enter job timeout in seconds: '
      read cli_timeout
   done

   while [[ $(validate 'throttle' "${cli_throttling}" 'no-log') == 'false' ]]; do

      printf 'Enter timeout throttling in seconds: '
      read cli_throttling
   done

   if [ -z "$cli_job_cmd" ]; then

      printf 'Enter job command: '
      read cli_job_cmd
   fi

   if [[ -z "$cli_fswatch_opt" ]]; then

      printf 'Enter fswatch options or skip: '
      read cli_fswatch_opt
   fi

   last_id=0
   : ${last_id:="${ids[0]}"}
   for n in "${ids[@]}" ; do

      ((n > last_id)) && last_id=$n
   done

   last_id=$((last_id+1))
   cli_id="$last_id"
   ids+=("$last_id")
   labels["$cli_id"]="$cli_label"
   paths["$cli_id"]="$cli_path"
   timeouts["$cli_id"]="$cli_timeout"
   throttles["$cli_id"]="$cli_throttling"
   job_cmds["$cli_id"]="$cli_job_cmd"
   fswatch_opts["$cli_id"]="$cli_fswatch_opt"
   params_str="<$cli_label><$cli_path><$cli_timeout><$cli_job_cmd><$cli_fswatch_opt>"

   while read line; do

      if [[ "$line" == *"$params_str" ]]; then

         printf 'Record already exists'
         exit
      fi

   done < "$jobs_file"

   cat /dev/null > "$jobs_file"
   cat /dev/null > "$tmp_file"

   for id in "${ids[@]}"; do

      echo "<$id><${labels[$id]}><${paths[$id]}><${timeouts[$id]}><${throttles[$id]}><${job_cmds[$id]}><${fswatch_opts[$id]}>" >> "$tmp_file"
   done

   sed '/^$/d' "$tmp_file" > "$jobs_file" # remove empty lines

   # restart service
   systemctl enable "$name.service"
   systemctl start "$name.service"
   systemctl daemon-reload

   printf 'Record with id: %s added\n' "$cli_id"
   printf 'disk label: %s\n' "$cli_label"
   printf 'path: %s\n' "$cli_path"
   printf 'job timeout: %s\n' "$cli_timeout"
   printf 'throttling: %s\n' "$cli_throttling"
   printf 'job command: %s\n' "$cli_job_cmd"
   printf 'fswatch options: %s\n' "$cli_fswatch_opt"
}
