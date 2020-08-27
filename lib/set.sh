#!/usr/bin/env bash

if [ "$cli_cmd" == 'set' ]; then

   read_jobs

   readonly NUM_RGX='^[0-9]+$'
   readonly UNSAFE_RGX="[\0\`\\\/:\;\*\"\'\<\>\|\.\,]" # UNSAFE SYMBOLS: \0 ` \ / : ; * " ' < > | . ,
   readonly SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount
   cli_label_ok=
   mount_point=
   mount_unit=

   while [ -z "$cli_label_ok" ] || [ "$cli_label_ok" == 'no' ]; do

      cli_label_ok='yes'

      if [ "$cli_label_ok" == 'yes' ] && [[ "$cli_label" =~ $UNSAFE_RGX ]]; then

         printf 'Disk label contains not a safe symbols\n'
         cli_label_ok='no'
      fi

      if [ "$cli_label_ok" == 'yes' ]; then

         # find mount point
         while read line; do

            if [[ "$line" =~ "$cli_label" ]]; then

               mount_point=$(echo "$line" | sed "$SED_CUT_MOUNT")
            fi
         done < <(lsblk -Ppo pkname,label,mountpoint)

         if [ -z "$mount_point" ]; then

            printf "Can't find mount point, try mount disk before: %s\n" "$cli_label"
            cli_label_ok='no'
         fi
      fi

      if [ "$cli_label_ok" == 'yes' ]; then

         mount_unit=$(systemctl list-units -t mount | awk 'match($0, /\ *(.+\.mount)\ */) { str=substr($0, RSTART, RLENGTH); print str }' | xargs -0 systemd-escape -u | grep "$cli_label" | awk '{$1=$1};1' | xargs -d '\n' systemd-escape | sed 's/\x/\\x/g')

         if [ -z "$mount_unit" ]; then

            printf "Can't find mount unit, for: %s\n" "$cli_label"
            cli_label_ok='no'
         fi
      fi

      if [ "$cli_label_ok" == 'no' ] || [ -z "$cli_label" ]; then

         printf 'Enter disk label: '
         read cli_label
      fi
   done

   # add systemd lines
   readonly conditionPathIsMountPoint="ConditionPathIsMountPoint=|$mount_point"
   readonly wantedBy="WantedBy=$mount_unit"
   awk -v conditionPathIsMountPoint="$conditionPathIsMountPoint" -v wantedBy="$wantedBy" '/\[Unit\]/ { print; print conditionPathIsMountPoint; next }; /\[Install\]/ { print; print wantedBy; next }1' "$SERVICE_FILE" | uniq > "$TMP_FILE"
   mv -f "$TMP_FILE" "$SERVICE_FILE" 2> /dev/null || {
      printf "Can't write service file, permission denied: %s\n" "$SERVICE_FILE"
      exit
   }

   watch_path=
   cli_path_ok=

   while [ ! -z "$cli_path" ] && { [ -z "$cli_path_ok" ] || [ "$cli_path_ok" == 'no' ]; }; do

      cli_path=$(echo "$cli_path" | sed 's/^\(\.\/\|\/\)//')
      watch_path="$mount_point/$cli_path"

      if [ -f "$watch_path" ] || [ -d "$watch_path" ]; then

         break
      fi

      printf 'Enter path: '
      read cli_path
   done

   while [[ ! "$cli_timeout" =~ $NUM_RGX ]]; do

      printf 'Enter job timeout in seconds: '
      read cli_timeout
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
   job_cmds["$cli_id"]="$cli_job_cmd"
   fswatch_opts["$cli_id"]="$cli_fswatch_opt"
   params_str="<$cli_label><$cli_path><$cli_timeout><$cli_job_cmd><$cli_fswatch_opt>"

   while read line; do

      if [[ "$line" == *"$params_str" ]]; then

         printf 'Record already exists'
         exit
      fi

   done < "$JOBS_FILE"

   cat /dev/null > "$JOBS_FILE"
   cat /dev/null > "$TMP_FILE"

   for id in "${ids[@]}"; do

      echo "<$id><${labels[$id]}><${paths[$id]}><${timeouts[$id]}><${job_cmds[$id]}><${fswatch_opts[$id]}>" >> "$TMP_FILE"
   done

   sed '/^$/d' "$TMP_FILE" > "$JOBS_FILE" # remove empty lines

   # restart service
   systemctl enable "$NAME.service"
   systemctl start "$NAME.service"
   systemctl daemon-reload

   printf 'Record with id: %s added\n' "$cli_id"
   printf 'disk label: %s\n' "$cli_label"
   printf 'path: %s\n' "$cli_path"
   printf 'job timeout: %s\n' "$cli_timeout"
   printf 'job command: %s\n' "$cli_job_cmd"
   printf 'fswatch options: %s\n' "$cli_fswatch_opt"
fi
