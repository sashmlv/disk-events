#!/bin/bash

# CLI FORMAT: sudo ./disk-events.sh set --label=<disk label> --path=<path> --timeout=<timeout> --command=<command> --fswatch=<fswatch options>

NAME='disk-events'
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
JOB_FILE="$DIR/$NAME-job.sh"
JOBS_FILE="./tmp/$NAME.jobs"
TMP_FILE="./tmp/$NAME.tmp"
SERVICE_FILE="/etc/systemd/system/$NAME.service"

# FUNCTIONS ----------------------------------------------------------------------------------------

ids=()
declare -A labels
declare -A paths
declare -A timeouts
declare -A job_cmds
declare -A fswatch_opts

function read_jobs {

   JOB_RGX='^<[0-9]+><.+><.*><[0-9]+><.+><.*>$' # match job line

   AWK_CUT_JOB_ID='match($0, /^<[0-9]+>/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # id
   AWK_CUT_JOB_LABEL='{ sub(/^<[0-9]+></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # disk label
   AWK_CUT_JOB_PATH='{ sub(/^<[0-9]+><[^>]*></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # watch path
   AWK_CUT_JOB_TIMEOUT='{ sub(/^<[0-9]+><[^>]*><[^>]*></, "" )}; match($0, /^[0-9]+[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # job timeout
   AWK_CUT_JOB_COMMAND='{ sub(/^<[0-9]+><[^>]*><[^>]*><[0-9]+></, "" ); sub(/><.*>$/, "" ); print $0 }' # job command
   AWK_CUT_JOB_FSWATCH='match($0, /<[^<]*>$/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # fswatch options

   id=
   label=
   path=
   timeout=
   job_cmd=
   fswatch_opt=

   if [ ! -f "$JOBS_FILE" ]; then

      printf 'Job file not found\n'
      exit
   fi

   while read line; do

      if [ ! -z "$line" ]; then

         if [[ "$line" =~ $JOB_RGX ]]; then

            id=$(echo "$line" | awk "$AWK_CUT_JOB_ID")
            label=$(echo "$line" | awk "$AWK_CUT_JOB_LABEL")
            path=$(echo "$line" | awk "$AWK_CUT_JOB_PATH")
            timeout=$(echo "$line" | awk "$AWK_CUT_JOB_TIMEOUT")
            job_cmd=$(echo "$line" | awk "$AWK_CUT_JOB_COMMAND")
            fswatch_opt=$(echo "$line" | awk "$AWK_CUT_JOB_FSWATCH")

            ids+=("$id")
            labels["$id"]="$label"
            paths["$id"]="$path"
            timeouts["$id"]="$timeout"
            job_cmds["$id"]="$job_cmd"
            fswatch_opts["$id"]="$fswatch_opt"
         else

            printf 'Wrong line in the jobs file:\n'
            printf '%s\n' "$line"
            exit
         fi
      fi
   done < "$JOBS_FILE"
}

function print_jobs {

   read_jobs

   id_title='id'
   label_title='label'
   path_title='path'
   timeout_title='timeout'
   job_cmd_title='command'
   fswatch_opt_title='fswatch options'

   fields=('id' 'label' 'path' 'timeout' 'job_cmd' 'fswatch_opt')

   value_length=
   title_length=

   declare -A values_lengths

   for field in "${fields[@]}"; do

      eval values_lengths["$field"]="\${#${field}_title}" # get title length
   done

   # get values max length for each field
   for id in "${ids[@]}"; do

      for field in "${fields[@]}"; do

         if [ "$field" == 'id' ]; then

            eval value_length="\${#id}"
         else

            eval value_length="\${#${field}s[$id]}"
         fi

         eval title_length="\${#${field}_title}"

         if [[ "$value_length" -gt "${values_lengths[$field]}" ]]; then

            values_lengths["$field"]="$value_length"

            if [[ "${values_lengths[$field]}" -lt "$title_length" ]]; then

               values_lengths["$field"]=$(("$title_length"-2))
            fi
         fi
      done
   done

   # add two whitespaces
   for field in "${!values_lengths[@]}"; do

      values_lengths["$field"]=$(("${values_lengths[$field]}"+2))
   done

   # 1 line
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['id']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['label']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['path']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
   printf '+\n'
   # 2 line
   printf "|\033[1m $id_title\033[0m"
   printf '%'$(("${values_lengths['id']}"-1-"${#id_title}"))'s'
   printf "|\033[1m $label_title\033[0m"
   printf '%'$(("${values_lengths['label']}"-1-"${#label_title}"))'s'
   printf "|\033[1m $path_title\033[0m"
   printf '%'$(("${values_lengths['path']}"-1-"${#path_title}"))'s'
   printf "|\033[1m $timeout_title\033[0m"
   printf '%'$(("${values_lengths['timeout']}"-1-"${#timeout_title}"))'s'
   printf "|\033[1m $job_cmd_title\033[0m"
   printf '%'$(("${values_lengths['job_cmd']}"-1-"${#job_cmd_title}"))'s'
   printf "|\033[1m $fswatch_opt_title\033[0m"
   printf '%'$(("${values_lengths['fswatch_opt']}"-1-"${#fswatch_opt_title}"))'s'
   printf '|\n'
   # 3 line
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['id']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['label']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['path']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
   printf '+\n'
   if [[ "${#ids[@]}" -gt 0 ]]; then

      for id in "${ids[@]}"; do
         # 4 line
         printf "| $id"
         printf '%'$(("${values_lengths['id']}"-1-"${#id}"))'s'
         printf "| ${labels[$id]}"
         printf '%'$(("${values_lengths['label']}"-1-"${#labels[$id]}"))'s'
         printf "| ${paths[$id]}"
         printf '%'$(("${values_lengths['path']}"-1-"${#paths[$id]}"))'s'
         printf "| ${timeouts[$id]}"
         printf '%'$(("${values_lengths['timeout']}"-1-"${#timeouts[$id]}"))'s'
         printf "| ${job_cmds[$id]}"
         printf '%'$(("${values_lengths['job_cmd']}"-1-"${#job_cmds[$id]}"))'s'
         printf "| ${fswatch_opts[$id]}"
         printf '%'$(("${values_lengths['fswatch_opt']}"-1-"${#fswatch_opts[$id]}"))'s'
         printf '|\n'
         # 5 line
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['id']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['label']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['path']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
         printf '+\n'
      done
   else
      # 5 line
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['id']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['label']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['path']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
      printf '+\n'
   fi
}

# CHECK UTILS ---------------------------------------------------------------------------------------

if [ ! -x "$(command -v fswatch)" ]; then

   printf '"fswatch" not found, please install "fswatch"\n'
   exit
fi

# CLI ARGUMENTS -------------------------------------------------------------------------------------

cli_cmd=$1
cli_id=
cli_label=
cli_path=
cli_timeout=
cli_job_cmd=
cli_fswatch_opt=

if [ ! -z "$cli_cmd" ]; then shift; fi

if [ ! -z "$*" ]; then

   AWK_CUT_ARG_LABEL='match($0, /(--label\ |--label=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--label\ |--label=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_PATH='match($0, /(--path\ |--path=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--path\ |--path=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_TIMEOUT='match($0, /(--timeout\ |--timeout=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--timeout\ |--timeout=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_COMMAND='match($0, /(--command\ |--command=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--command\ |--command=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_FSWATCH='match($0, /(--fswatch\ |--fswatch=)[\47"].+[\47"]/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--fswatch\ |--fswatch=)[\47|"]|[\47|"]$/, "", str); print str }'

   cli_label=$(echo "$*" | awk "$AWK_CUT_ARG_LABEL")
   cli_path=$(echo "$*" | awk "$AWK_CUT_ARG_PATH")
   cli_timeout=$(echo "$*" | awk "$AWK_CUT_ARG_TIMEOUT")
   cli_job_cmd=$(echo "$*" | awk "$AWK_CUT_ARG_COMMAND")
   cli_fswatch_opt=$(echo "$*" | awk "$AWK_CUT_ARG_FSWATCH")
fi

# COMMAND -------------------------------------------------------------------------------------------

COMMANDS=('set' 'unset' 'print' 'uninstall' 'quit')

if [ -z "$cli_cmd" ] || [[ ! " ${COMMANDS[@]} " =~ " ${cli_cmd} " ]]; then

   echo 'Select command: '
   echo '1. set disk'
   echo '2. unset disk'
   echo '3. print jobs'
   echo '4. uninstall'
   echo '5. quit'
   read cli_cmd
   case "$cli_cmd" in
      1) cli_cmd='set';;
      2) cli_cmd='unset';;
      3) cli_cmd='print';;
      4) cli_cmd='uninstall';;
      5) cli_cmd='quit';;
      *)
         echo "Invalid option $cli_cmd"
         exit
         ;;
   esac
fi

# QUIT ----------------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'quit' ]; then printf '%s' "$cli_cmd"; exit; fi

# UNINSTALL -----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'uninstall' ]; then

   systemctl stop "$NAME.service"
   systemctl disable "$NAME.service"
   systemctl daemon-reload
   rm -f "$SERVICE_FILE"
   exit
fi

# PRINT JOBS ----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'print' ]; then

   print_jobs
   exit
fi

# INSTALL -------------------------------------------------------------------------------------------

# add jobs file
if [ ! -f "$JOBS_FILE" ]; then

   touch "$JOBS_FILE"
fi

# fix jobs file
if [ ! -f "JOB_FILE" ]; then

   chmod +x "$JOB_FILE"
fi

# add service for disk mount/unmount monitoring
if [ ! -f "$SERVICE_FILE" ]; then

   touch "$SERVICE_FILE" 2> /dev/null || {
      printf "Can't write service file, permission denied: %s\n" "$SERVICE_FILE"
      exit
   }

   cat > "$SERVICE_FILE" <<EOF
[Unit]

[Service]
KillMode=process
ExecStart=$JOB_FILE --log=true

[Install]
EOF
fi

# SET RECORD ----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'set' ]; then

   read_jobs

   NUM_RGX='^[0-9]+$'
   UNSAFE_RGX="[\0\`\\\/:\;\*\"\'\<\>\|\.\,]" # UNSAFE SYMBOLS: \0 ` \ / : ; * " ' < > | . ,
   SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount
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

   # add service lines
   conditionPathIsMountPoint="ConditionPathIsMountPoint=|$mount_point"
   wantedBy="WantedBy=$mount_unit"
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

   cli_id=$(("${#ids[@]}"+1))
   ids+=("$cli_id")
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

# UNSET RECORD --------------------------------------------------------------------------------------

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
