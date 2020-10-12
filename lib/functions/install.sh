#!/usr/bin/env bash

# add files
# add service file with data from jobs file
# start service

function install {

   # add log file
   if [[ ! -f "$log_file" ]]; then

      touch "$log_file"
      printf "Log file created: %s\n" "$log_file"
   fi

   # add jobs file
   if [[ ! -f "$jobs_file" ]]; then

      touch "$jobs_file"
      log "install: File for jobs created: %s\n" "$jobs_file"
   fi

   # fix process file
   if [[ -f "$process_file" ]] && [[ ! -x "$process_file" ]] ; then

      chmod +x "$process_file"
      log "install: Added execute permissions for process file: %s\n" "$process_file"
   fi

   # add service for disk mount/unmount monitoring
   if [[ ! -f "$service_file" ]] || [[ ! -s "$service_file" ]]; then

      touch "$service_file" 2> /dev/null || {
         log "install: Can't write service file, permission denied: %s\n" "$service_file"
         exit
      }

      cat > "$service_file" <<EOF
[Unit]

[Service]
KillMode=process
WorkingDirectory=$dir
ExecStart=$process_file --logger=true

[Install]
EOF

      log "install: Service file added: %s\n" "$service_file"
   fi

   # if we have jobs, check service file for mount points
   if [[ "${#labels[@]}" -gt 0 ]]; then

      # get 'Unit', 'Install' lines from service file
      units=()
      installs=()
      while IFS= read -r line; do

         if [[ "${line}" == "ConditionPathIsMountPoint=|"* ]]; then

            unit=$(echo "${line}" | sed 's/ConditionPathIsMountPoint=|//')
            units+=("${unit}")
            continue
         fi

         if [[ "${line}" == "WantedBy="* ]]; then

            install+=$(echo "${line}" | sed 's/WantedBy=//')
            installs+=("${install}")
            continue
         fi
      done < "${service_file}"

      # fix service file if label not found in it
      for label in "${labels[@]}"; do

         found_unit=false
         found_install=false
         label_mount=$(echo "${label}" | xargs -r -d '\n' systemd-escape | sed "s/$/.mount/")

         for unit in "${units[@]}"; do

            if [[ "${unit}" == *"${label}" ]]; then

               found_unit=true
               break
            fi
         done

         for install in "${installs[@]}"; do

            if [[ "${install}" == *"${label_mount}" ]]; then

               found_install=true
               break
            fi
         done

         if [[ "${found_unit}" == "false" ]] || [[ "${found_install}" == "false" ]]; then

            mount_point=$(get_mount_point "${label}" 'no-log') # try to get point
            mount_unit=$(get_mount_unit "${label}" 'no-log') # try to get unit

            if [[ ! "${mount_point}" == "false" ]] && [[ ! "${mount_unit}" == "false" ]]; then

               # add systemd lines
               declare conditionPathIsMountPoint="ConditionPathIsMountPoint=|$mount_point"
               declare wantedBy="WantedBy=$mount_unit"
               awk -v conditionPathIsMountPoint="$conditionPathIsMountPoint" -v wantedBy="$wantedBy" '/\[Unit\]/ { print; print conditionPathIsMountPoint; next }; /\[Install\]/ { print; print wantedBy; next }1' "$service_file" | awk '!NF || !x[$0]++' > "$tmp_file"
               mv -f "$tmp_file" "$service_file" 2> /dev/null || {
                  printf "Can't write service file, permission denied: %s\n" "$service_file"
                  exit
               }

               # restart service
               systemctl enable "$name.service"
               systemctl start "$name.service"
               systemctl daemon-reload
               log "install: Service file fixed: %s, service started: %s\n" "$service_file" "$name.service"
           fi
         fi
      done
   fi
}