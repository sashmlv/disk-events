#!/bin/bash

# CLI FORMAT: sudo ./disk-events.sh set --label=<disk label> --path=<path> --timeout=<timeout> --command=<command> --fswatch=<fswatch options>

NAME='disk-events'
COMMANDS=('set' 'unset' 'print' 'uninstall' 'quit')
SOURCE_JOB_FILE="./$NAME-job.sh"
TARGET_JOB_FILE="/home/$USER/bin/$NAME-job.sh"
CONFIG_FILE="/home/$USER/bin/$NAME.conf"
SERVICE_FILE="/etc/systemd/system/$NAME.service"
TMP_FILE='/tmp/$NAME.tmp'
NUM_RGX='^[0-9]+$' # it's number
CONFIG_RGX='^<.+><.*><[0-9]+><.+><.*>$' # match config line
LABEL_RGX='^After=.+\.mount$' # contains disk label
SED_CUT_LABEL='s/\(After=.\+\-\|\.mount\)//g' # cut disk label
SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount
AWK_CUT_CONFIG_LABEL='match($0, /^<[^>]*>/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # disk label
AWK_CUT_CONFIG_PATH='{ sub(/^<[^>]*></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # watch path
AWK_CUT_CONFIG_TIMEOUT='{ sub(/^<[^>]*><[^>]*></, "" )}; match($0, /^[0-9]+[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # job timeout
AWK_CUT_CONFIG_COMMAND='{ sub(/^<[^>]*><[^>]*><[0-9]+></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # job command
AWK_CUT_CONFIG_FSWATCH='match($0, /<[^<]*>$/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # fswatch options
AWK_CUT_ARG_LABEL='match($0, /(-l\ |-l=|--label\ |--label=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-l\ |-l=|--label\ |--label=)|\ $/, "", str); print str }'
AWK_CUT_ARG_PATH='match($0, /(-p\ |-p=|--path\ |--path=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-p\ |-p=|--path\ |--path=)|\ $/, "", str); print str }'
AWK_CUT_ARG_TIMEOUT='match($0, /(-t\ |-t=|--timeout\ |--timeout=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-t\ |-t=|--timeout\ |--timeout=)|\ $/, "", str); print str }'
AWK_CUT_ARG_COMMAND='match($0, /(-c\ |-c=|--command\ |--command=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-c\ |-c=|--command\ |--command=)|\ $/, "", str); print str }'
AWK_CUT_ARG_FSWATCH='match($0, /(-f\ |-f=|--fswatch\ |--fswatch=)[\47"].+[\47"]/) { str=substr($0, RSTART, RLENGTH); gsub( /^(-f\ |-f=|--fswatch\ |--fswatch=)[\47|"]|[\47|"]$/, "", str); print str }'

cli_cmd=$1
cli_label=
cli_path=
cli_timeout=
cli_job_cmd=
cli_fswatch=

labels=()
declare -A paths
declare -A timeouts
declare -A cmds
declare -A fswatch_opts

cmd=
label=
path=
timeout=
job_cmd=
fswatch=

label_title=' label '
timeout_title=' timeout '
cmd_title=' command '
label_length=0
timeout_length=0
cmd_length=0

# FUNCTIONS ----------------------------------------------------------------------------------------

function clean_exit {

   rm -f "$TMP_FILE"
   exit
}

function read_config {

   if [ ! -f "$CONFIG_FILE" ]; then

      printf 'Config file not found'
      exit
   fi

   while read line; do

      if [ ! -z "$line" ]; then

         if [[ "$line" =~ $CONFIG_RGX ]]; then

            label=$(echo "$line" | awk "$AWK_CUT_CONFIG_LABEL")
            path=$(echo "$line" | awk "$AWK_CUT_CONFIG_PATH")
            timeout=$(echo "$line" | awk "$AWK_CUT_CONFIG_TIMEOUT")
            job_cmd=$(echo "$line" | awk "$AWK_CUT_CONFIG_COMMAND")
            fswatch=$(echo "$line" | awk "$AWK_CUT_CONFIG_FSWATCH")

            labels+=("$label")
            paths["$label"]="$path"
            timeouts["$label"]="$timeout"
            cmds["$label"]="$cmd"
            fswatch_opts["$label"]="$fswatch_opts"
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

if [ ! -z "$cli_cmd" ]; then shift; fi

if [ ! -z "$*" ]; then

   cli_label=$(echo "$*" | awk "$AWK_CUT_ARG_LABEL")
   cli_path=$(echo "$*" | awk "$AWK_CUT_ARG_PATH")
   cli_timeout=$(echo "$*" | awk "$AWK_CUT_ARG_TIMEOUT")
   cli_job_cmd=$(echo "$*" | awk "$AWK_CUT_ARG_COMMAND")
   cli_fswatch=$(echo "$*" | awk "$AWK_CUT_ARG_FSWATCH")
fi

# COMMAND -------------------------------------------------------------------------------------------

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

   if [[ "${#labels[@]}" -eq 0 ]]; then

      printf 'There are no config data'
      exit
   fi

   for label in "${labels[@]}"; do

      if [[ "${#label}" -gt "$label_length" ]]; then

         label_length=$(("${#label}"+2))

         if [[ "$label_length" -lt "${#label_title}" ]]; then

            label_length="${#label_title}"
         fi
      fi

      if [[ "${#timeouts[$label]}" -gt "$timeout_length" ]]; then

         timeout_length=$(("${#timeouts[$label]}"+2))

         if [[ "$timeout_length" -lt "${#timeout_title}" ]]; then

            timeout_length="${#timeout_title}"
         fi
      fi

      if [[ "${#cmds[$label]}" -gt "$cmd_length" ]]; then

         cmd_length=$(("${#cmds[$label]}"+2))

         if [[ "$cmd_length" -lt "${#cmd_title}" ]]; then

            cmd_length="${#cmd_title}"
         fi
      fi
   done

   # 1 line
   printf '+'
   printf '%0.s-' $(seq 1 "$label_length")
   printf '+'
   printf '%0.s-' $(seq 1 "$timeout_length")
   printf '+'
   printf '%0.s-' $(seq 1 "$cmd_length")
   printf '+\n'
   # 2 line
   printf "|\033[1m$label_title\033[0m"
   printf '%'$(("$label_length"-"${#label_title}"))'s'
   printf "|\033[1m$timeout_title\033[0m"
   printf '%'$(("$timeout_length"-"${#timeout_title}"))'s'
   printf "|\033[1m$cmd_title\033[0m"
   printf '%'$(("$cmd_length"-"${#cmd_title}"))'s'
   printf '|\n'
   # 3 line
   printf '+'
   printf '%0.s-' $(seq 1 "$label_length")
   printf '+'
   printf '%0.s-' $(seq 1 "$timeout_length")
   printf '+'
   printf '%0.s-' $(seq 1 "$cmd_length")
   printf '+\n'

   for label in "${labels[@]}"; do

      # 4 line
      printf "| $label"
      printf '%'$(("$label_length"-1-"${#label}"))'s'
      printf '| '"${timeouts[$label]}"
      printf '%'$(("$timeout_length"-1-"${#timeouts[$label]}"))'s'
      printf '| '"${cmds[$label]}"
      printf '%'$(("$cmd_length"-1-"${#cmds[$label]}"))'s'
      printf '|\n'
      # 5 line
      printf '+'
      printf '%0.s-' $(seq 1 "$label_length")
      printf '+'
      printf '%0.s-' $(seq 1 "$timeout_length")
      printf '+'
      printf '%0.s-' $(seq 1 "$cmd_length")
      printf '+\n'
   done
   exit
fi

# CHECKS --------------------------------------------------------------------------------------------

UNSAFE_RGX="[\0\`\\\/:\;\*\"\'\<\>\|\.\,]" # UNSAFE SYMBOLS: \0 ` \ / : ; * " ' < > | . ,
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

if [ "$cli_cmd" == 'set' ] && [[ -z "$cli_fswatch" ]]; then

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

   exit

   read_config

   cat /dev/null > "$CONFIG_FILE"
   cat /dev/null > "$TMP_FILE"

   if [[ ! " ${labels[@]} " =~ " ${cli_label} " ]]; then

      labels+=("$cli_label")
   fi

   timeouts["$cli_label"]="$cli_timeout"
   cmds["$cli_label"]="$cli_job_cmd"

   for label in "${labels[@]}"; do

      echo "<$label><${timeouts[$label]}><${cmds[$label]}>" >> "$TMP_FILE"
   done

   sed '/^$/d' "$TMP_FILE" > "$CONFIG_FILE" # remove empty lines

   # add service lines and restart service
   after="After=$mount_unit"
   wantedBy="WantedBy=$mount_unit"
   awk -v after="$after" -v wantedBy="$wantedBy" '/\[Unit\]/ { print; print after; next }; /\[Install\]/ { print; print wantedBy; next }1' "$SERVICE_FILE" | uniq > "$TMP_FILE"
   mv "$TMP_FILE" "$SERVICE_FILE"

   systemctl enable "$NAME.service"
   systemctl start "$NAME.service"
   systemctl daemon-reload

   echo
   echo 'Added:'
   echo "disk label: $cli_label"
   echo "job timeout: $cli_timeout"
   echo "job command: $cli_job_cmd"
fi

# UNSET DISK ----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'unset' ]; then

   exit

   sed "/$cli_label/d" "$CONFIG_FILE" > "$TMP_FILE"
   mv "$TMP_FILE" "$CONFIG_FILE"

   systemctl daemon-reload

   echo "$cli_cmd $cli_label"
fi
