#!/bin/bash

# CLI FORMAT: sudo ./disk-events.sh set --label=<disk label> --path=<path> --timeout=<timeout> --command=<command> --fswatch=<fswatch options>

NAME='disk-events'
SOURCE_JOB_FILE="./$NAME-job.sh"
TARGET_JOB_FILE="/home/$USER/bin/$NAME-job.sh"
CONFIG_FILE="/home/$USER/bin/$NAME.conf"
SERVICE_FILE="/etc/systemd/system/$NAME.service"
TMP_FILE='/tmp/$NAME.tmp'

# FUNCTIONS ----------------------------------------------------------------------------------------

function clean_exit {

   rm -f "$TMP_FILE"
   exit
}

CONFIG_RGX='^<[0-9]+><.+><.*><[0-9]+><.+><.*>$' # match config line
AWK_CUT_CONFIG_ID='match($0, /^<[0-9]+[^>]*>/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # id
AWK_CUT_CONFIG_LABEL='{ sub(/^<[0-9]+[^>]*></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # disk label
AWK_CUT_CONFIG_PATH='{ sub(/^<[0-9]+[^>]*><[^>]*></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # watch path
AWK_CUT_CONFIG_TIMEOUT='{ sub(/^<[0-9]+[^>]*><[^>]*><[^>]*></, "" )}; match($0, /^[0-9]+[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # job timeout
AWK_CUT_CONFIG_COMMAND='{ sub(/^<[0-9]+[^>]*><[^>]*><[^>]*><[0-9]+></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # job command
AWK_CUT_CONFIG_FSWATCH='match($0, /<[^<]*>$/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # fswatch options

id=
label=
path=
timeout=
job_cmd=
fswatch_opt=

ids=()
declare -A labels
declare -A paths
declare -A timeouts
declare -A job_cmds
declare -A fswatch_opts

function read_config {

   if [ ! -f "$CONFIG_FILE" ]; then

      printf 'Config file not found'
      exit
   fi

   while read line; do

      if [ ! -z "$line" ]; then

         if [[ "$line" =~ $CONFIG_RGX ]]; then

            id=$(echo "$line" | awk "$AWK_CUT_CONFIG_ID")
            label=$(echo "$line" | awk "$AWK_CUT_CONFIG_LABEL")
            path=$(echo "$line" | awk "$AWK_CUT_CONFIG_PATH")
            timeout=$(echo "$line" | awk "$AWK_CUT_CONFIG_TIMEOUT")
            job_cmd=$(echo "$line" | awk "$AWK_CUT_CONFIG_COMMAND")
            fswatch_opt=$(echo "$line" | awk "$AWK_CUT_CONFIG_FSWATCH")

            ids+=("$id")
            labels["$id"]="$label"
            paths["$id"]="$path"
            timeouts["$id"]="$timeout"
            job_cmds["$id"]="$job_cmd"
            fswatch_opts["$id"]="$fswatch_opt"
         else

            echo "Wrong line in the config:"
            echo "$line"
            clean_exit
         fi
      fi
   done < "$CONFIG_FILE"
}

# CHECK UTILS ---------------------------------------------------------------------------------------

if [ ! -x "$(command -v fswatch)" ]; then

   echo '"fswatch" not found, please install "fswatch"'
   exit
fi

if [ ! -x "$(command -v sdparm)" ]; then

   echo '"sdparm" not found, please install "sdparm"'
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

   AWK_CUT_ARG_LABEL='match($0, /(-l\ |-l=|--label\ |--label=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-l\ |-l=|--label\ |--label=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_PATH='match($0, /(-p\ |-p=|--path\ |--path=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-p\ |-p=|--path\ |--path=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_TIMEOUT='match($0, /(-t\ |-t=|--timeout\ |--timeout=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-t\ |-t=|--timeout\ |--timeout=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_COMMAND='match($0, /(-c\ |-c=|--command\ |--command=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-c\ |-c=|--command\ |--command=)|\ $/, "", str); print str }'
   AWK_CUT_ARG_FSWATCH='match($0, /(-f\ |-f=|--fswatch\ |--fswatch=)[\47"].+[\47"]/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-f\ |-f=|--fswatch\ |--fswatch=)[\47|"]|[\47|"]$/, "", str); print str }'

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
   echo '3. print config'
   echo '4. uninstall'
   echo '5. quit'
   read cli_cmd
   case "$cli_cmd" in
      1) cli_cmd='set';;
      2) cli_cmd='unset';;
      3) cli_cmd='print';;
      4) cli_cmd='uninstall';;
      5) cli_cmd='quit';;
      *) echo "Invalid option $cli_cmd";;
   esac
fi

# QUIT ----------------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'quit' ]; then echo "$cli_cmd"; exit; fi

# UNINSTALL -----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'uninstall' ]; then

   systemctl stop "$NAME.service"
   systemctl disable "$NAME.service"
   systemctl daemon-reload
   rm -f "$CONFIG_FILE" "$TARGET_JOB_FILE" "$SERVICE_FILE" "$TMP_FILE"
   exit
fi

# PRINT CONFIG --------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'print' ]; then

   read_config

   id_title=' id '
   label_title=' label '
   path_title=' path '
   timeout_title=' timeout '
   job_cmd_title=' command '
   fswatch_opt_title=' fswatch options '

   fields=('id' 'label' 'path' 'timeout' 'job_cmd' 'fswatch_opt')

   declare -A values_lengths

   for field in "${fields[@]}"; do

      values_lengths["$field"]=0
   done

   value_length=
   title_length=
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
   printf "|\033[1m$id_title\033[0m"
   printf '%'$(("${values_lengths['id']}"-"${#id_title}"))'s'
   printf "|\033[1m$label_title\033[0m"
   printf '%'$(("${values_lengths['label']}"-"${#label_title}"))'s'
   printf "|\033[1m$path_title\033[0m"
   printf '%'$(("${values_lengths['path']}"-"${#path_title}"))'s'
   printf "|\033[1m$timeout_title\033[0m"
   printf '%'$(("${values_lengths['timeout']}"-"${#timeout_title}"))'s'
   printf "|\033[1m$job_cmd_title\033[0m"
   printf '%'$(("${values_lengths['job_cmd']}"-"${#job_cmd_title}"))'s'
   printf "|\033[1m$fswatch_opt_title\033[0m"
   printf '%'$(("${values_lengths['fswatch_opt']}"-"${#fswatch_opt_title}"))'s'
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
   exit
fi

# CHECKS --------------------------------------------------------------------------------------------

NUM_RGX='^[0-9]+$' # it's number
UNSAFE_RGX="[\0\`\\\/:\;\*\"\'\<\>\|\.\,]" # UNSAFE SYMBOLS: \0 ` \ / : ; * " ' < > | . ,
SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount
cli_label_ok=
mount_point=
mount_unit=

while [ -z "$cli_label_ok" ] || [ "$cli_label_ok" == 'no' ]; do

   cli_label_ok='yes'

   if [ "$cli_label_ok" == 'yes' ] && [[ "$cli_label" =~ $UNSAFE_RGX ]]; then

      echo 'Disk label contains not a safe symbols'
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

      mount_unit=$(systemctl list-units -t mount | awk 'match($0, /\ *(.+\.mount)\ */) { str=substr($0, RSTART, RLENGTH); print str }' | xargs -d '\n' printf "%b\n" | grep "$cli_label")

      if [ -z "$mount_unit" ]; then

         printf "Can't find mount unit, for: %s\n" "$cli_label"
         cli_label_ok='no'
      fi
   fi

   if [ "$cli_label_ok" == 'no' ]; then

      echo 'Enter disk label: '
      read cli_label
   fi
done

watch_path=
cli_path_ok=

while [ ! -z "$cli_path" ] && { [ -z "$cli_path_ok" ] || [ "$cli_path_ok" == 'no' ]; }; do

   cli_path=$(echo "$cli_path" | sed 's/^\(\.\/\|\/\)//')
   watch_path="$mount_point/$cli_path"

   if [ -f "$watch_path" ] || [ -d "$watch_path" ]; then

      break
   fi

   printf 'Path not found: %s\n' "$watch_path"
   printf 'Enter path: '
   read cli_path
done

while [ "$cli_cmd" == 'set' ] && [[ ! "$cli_timeout" =~ $NUM_RGX ]]; do

   echo 'Enter job timeout in seconds: '
   read cli_timeout
done

if [ "$cli_cmd" == 'set' ] && [ -z "$cli_job_cmd" ]; then

   printf "Default job command: sdparm --readonly --command=stop \$dev\nParameter \$dev the device path (/dev/sdx)\nEnter job command or skip for default: "
   read cli_job_cmd

   if [ -z "$cli_job_cmd" ]; then

      cli_job_cmd='sdparm --readonly --command=stop $dev'
   fi
fi

if [ "$cli_cmd" == 'set' ] && [[ -z "$cli_fswatch_opt" ]]; then

   printf 'Enter fswatch options or skip:'
   read cli_job_cmd
fi

# INSTALL -------------------------------------------------------------------------------------------

# add config file
if [ ! -f "$CONFIG_FILE" ]; then

   touch "$CONFIG_FILE"
fi

# add job file
if [ ! -f "$TARGET_JOB_FILE" ]; then

   cp "$SOURCE_JOB_FILE" "$TARGET_JOB_FILE"
   chmod +x "$TARGET_JOB_FILE"
fi

# add service for disk mount/unmount monitoring
if [ ! -f "$SERVICE_FILE" ]; then

   cat > "$SERVICE_FILE" <<EOF
[Unit]

[Service]
ExecStart=$TARGET_JOB_FILE

[Install]
EOF
fi

# SET DISK ------------------------------------------------------------------------------------------

# set disk
if [ "$cli_cmd" == 'set' ]; then

   read_config

   cli_id=$(("${#ids[@]}"+1))

   cat /dev/null > "$CONFIG_FILE"
   cat /dev/null > "$TMP_FILE"

   ids+=("$cli_id")
   labels["$cli_id"]="$cli_label"
   paths["$cli_id"]="$cli_path"
   timeouts["$cli_id"]="$cli_timeout"
   job_cmds["$cli_id"]="$cli_job_cmd"
   fswatch_opts["$cli_id"]="$cli_fswatch_opt"

   for id in "${ids[@]}"; do

      echo "<$id><${labels[$id]}><${paths[$id]}><${timeouts[$id]}><${job_cmds[$id]}><${fswatch_opts[$id]}>" >> "$TMP_FILE"
   done

   sed '/^$/d' "$TMP_FILE" > "$CONFIG_FILE" # remove empty lines

   # add service lines and restart service
   # after="After=$mount_unit"
   # wantedBy="WantedBy=$mount_unit"
   # awk -v after="$after" -v wantedBy="$wantedBy" '/\[Unit\]/ { print; print after; next }; /\[Install\]/ { print; print wantedBy; next }1' "$SERVICE_FILE" | uniq > "$TMP_FILE"
   # mv "$TMP_FILE" "$SERVICE_FILE"

   # systemctl enable "$NAME.service"
   # systemctl start "$NAME.service"
   # systemctl daemon-reload

   echo
   echo "Added $cli_id:"
   echo "disk label: $cli_label"
   echo "path: $cli_path"
   echo "job timeout: $cli_timeout"
   echo "job command: $cli_job_cmd"
   echo "fswatch options: $cli_fswatch_opt"
fi

# UNSET DISK ----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'unset' ]; then

   exit

   sed "/$cli_label/d" "$CONFIG_FILE" > "$TMP_FILE"
   mv "$TMP_FILE" "$CONFIG_FILE"

   systemctl daemon-reload

   echo "$cli_cmd $cli_label"
fi
