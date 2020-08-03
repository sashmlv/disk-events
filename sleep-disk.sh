#!/bin/bash

NAME='sleep-disk'
COMMANDS=('set' 'unset' 'print' 'uninstall' 'quit')
SOURCE_JOB_FILE="./$NAME-job.sh"
TARGET_JOB_FILE="/home/$USER/bin/$NAME-job.sh"
CONFIG_FILE="/home/$USER/bin/$NAME.conf"
SERVICE_FILE="/etc/systemd/system/$NAME.service"
TMP_FILE='/tmp/$NAME.tmp'
NUM_RGX='^[0-9]+$' # it's number
UNSAFE_RGX="[\0\`\\\/:\;\*\"\'\<\>\|\.\,]" # UNSAFE SYMBOLS: \0 ` \ / : ; * " ' < > | . ,
CONFIG_RGX='^<.+><[0-9]+><.+>$' # match config line
LABEL_RGX='^After=.+\.mount$' # contains disk label
SED_CUT_LABEL='s/\(After=.\+\-\|\.mount\)//g' # cut disk label
AWK_CUT_CONFIG_LABEL='{ sub(/^</, "") }; { sub(/><[0-9]+><.+$/, "") }1' # cut disk label
AWK_CUT_CONFIG_TIMEOUT='{ sub(/^<[^>]*></, "") }; { sub(/><[^>]*>$/, "") }1' # cut disk timeout
AWK_CUT_CONFIG_COMMAND='{ sub(/^.+</, "") }; { sub(/>$/, "") }1' # cut sleep command

cli_cmd=$1
cli_label=$2
cli_timeout=$3
cli_sleep_cmd=$4

labels=()
declare -A timeouts
declare -A cmds

cmd=
label=
timeout=
sleep_cmd=

label_title=' label '
timeout_title=' timeout '
cmd_title=' command '
label_length=0
timeout_length=0
cmd_length=0

function clean_exit {

   rm -f "$TMP_FILE"
   exit
}

function read_config {

   while read line; do

      if [ ! -z "$line" ]; then

         if [[ "$line" =~ $CONFIG_RGX ]]; then

            label=$(echo "$line" | awk "$AWK_CUT_CONFIG_LABEL")
            timeout=$(echo "$line" | awk "$AWK_CUT_CONFIG_TIMEOUT")
            cmd=$(echo "$line" | awk "$AWK_CUT_CONFIG_COMMAND")

            labels+=("$label")
            timeouts["$label"]="$timeout"
            cmds["$label"]="$cmd"
         else

            echo "Wrong line in the config:"
            echo "$line"
            clean_exit
         fi
      fi
   done < "$CONFIG_FILE"
}

# CHECK UTILS ---------------------------------------------------------------------------------------

if [ ! -x "$(command -v hdparm)" ]; then

   echo '"sdparm" not found, please install "sdparm"'
   exit
fi

if [ ! -x "$(command -v fswatch)" ]; then

   echo '"fswatch" not found, please install "fswatch"'
   exit
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

# COMMAND -------------------------------------------------------------------------------------------

# reset bad command input
if [ ! -z "$cli_cmd" ] && [[ ! " ${COMMANDS[@]} " =~ " ${cli_cmd} " ]]; then

   cli_cmd=''
fi

if [ -z "$cli_cmd" ]; then

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

# PRINT CONFIG --------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'print' ]; then

   read_config

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

# UNINSTALL -----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'uninstall' ]; then

   systemctl stop "$NAME.service"
   systemctl disable "$NAME.service"
   systemctl daemon-reload
   rm -f "$CONFIG_FILE" "$TARGET_JOB_FILE" "$SERVICE_FILE" "$TMP_FILE"
   exit
fi

# CHECKS --------------------------------------------------------------------------------------------

# reset bad timeout input
if [[ ! "$cli_timeout" =~ $NUM_RGX ]]; then

   cli_timeout=''
fi

while [ -z "$cli_label" ] || [[ "$cli_label" =~ $UNSAFE_RGX ]]; do

   if [[ "$cli_label" =~ $UNSAFE_RGX ]]; then

      echo 'Disk label contains not a safe symbols'
   fi

   echo 'Enter disk label: '
   read cli_label
done

while [ "$cli_cmd" == 'set' ] && [[ ! "$cli_timeout" =~ $NUM_RGX ]]; do

   echo 'Enter sleep timeout, in seconds: '
   read cli_timeout
done

while [ "$cli_cmd" == 'set' ] && [ -z "$sleep_command" ]; do

   echo 'Default sleep command: sdparm --readonly --command=stop $dev\n$dev - device path (/dev/sdx)\nCommand will executed like this: your-command-here $dev & \nEnter sleep command or skip for default: '
   read sleep_command
done

# SET DISK ------------------------------------------------------------------------------------------

# set disk
if [ "$cli_cmd" == 'set' ]; then

   # update config
   config["$cli_label"]="$cli_timeout"

   cat /dev/null > "$CONFIG_FILE"
   cat /dev/null > "$TMP_FILE"

   for label in "${!config[@]}"; do

      echo "<$label><${config[$label]}>" >> "$TMP_FILE"
   done

   sed '/^$/d' "$TMP_FILE" > "$CONFIG_FILE" # remove empty lines

   # get mount point
   mount_point=$(systemctl list-units -t mount | sed "s/\s\+/|/g" | awk -F '|' '/\.mount/{ print $2 }' | xargs -0 printf %b | grep "$cli_label")

   if [ -z "$mount_point" ]; then

      echo "Can't find mount point, try mount disk"
      clean_exit
   fi

   # add service lines and restart service
   after="After=$mount_point"
   wantedBy="WantedBy=$mount_point"
   awk -v after="$after" -v wantedBy="$wantedBy" '/\[Unit\]/ { print; print after; next }; /\[Install\]/ { print; print wantedBy; next }1' "$SERVICE_FILE" | uniq > "$TMP_FILE"
   mv "$TMP_FILE" "$SERVICE_FILE"

   systemctl enable "$NAME.service"
   systemctl start "$NAME.service"
   systemctl daemon-reload

   echo "$cli_cmd $cli_label, will sleep after $cli_timeout seconds"
fi

# UNSET DISK ----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'unset' ]; then

   sed "/$cli_label/d" "$CONFIG_FILE" > "$TMP_FILE"
   mv "$TMP_FILE" "$CONFIG_FILE"

   systemctl enable "$NAME.service"
   systemctl start "$NAME.service"
   systemctl daemon-reload

   echo "$cli_cmd $cli_label"
fi
