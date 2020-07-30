#!/bin/bash

declare -A config
key=
value=
cmd=$1
disk_label=$2
timeout=$3
NAME='sleep-disk'
COMMANDS=('set' 'unset' 'uninstall' 'quit')
SOURCE_JOB_FILE="./$NAME-job.sh"
TARGET_JOB_FILE="/home/$USER/bin/$NAME-job.sh"
CONFIG_FILE="/home/$USER/bin/$NAME.conf"
SERVICE_FILE="/etc/systemd/system/$NAME.service"
TMP_FILE='./temporary_file.tmp'
NUM_RGX='^[0-9]+$' # it's number
UNSAFE_RGX="[\0\`\\\/:\;\*\"\'\<\>\|\.\,]" # UNSAFE SYMBOLS: \0 ` \ / : ; * " ' < > | . ,
DISK_LABEL_RGX='^After=.+\.mount$' # contains disk label
CONFIG_RGX='^<.+><[0-9]+>$' # match config line
SED_CUT_LABEL='s/\(After=.\+\-\|\.mount\)//g' # cut disk label
SED_CUT_CONFIG_KEY='s/^\(<\)\|\(><.\+>\)$//g' # cut key from config line
SED_CUT_CONFIG_VAL='s/^\(<.\+><\)\|\(>\)$//g' # cut val from config line

function clean_exit {

   rm -f "$TMP_FILE"
   exit
}

# CHECK UTILS ---------------------------------------------------------------------------------------

if [ ! -x "$(command -v hdparm)" ]; then

   echo '"hdparm" not found, please install "hdparm"'
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
if [ ! -z "$cmd" ] && [[ ! " ${COMMANDS[@]} " =~ " ${cmd} " ]]; then

   cmd=''
fi

if [ -z "$cmd" ]; then

   echo 'Select command: '
   echo '1. set disk'
   echo '2. unset disk'
   echo '3. uninstall'
   echo '4. quit'
   read cmd
   case "$cmd" in
      1) cmd='set';;
      2) cmd='unset';;
      3) cmd='uninstall';;
      4) cmd='quit';;
      *) echo "Invalid option $cmd";;
   esac
fi

# QUIT ----------------------------------------------------------------------------------------------

if [ "$cmd" == 'quit' ]; then echo "$cmd"; exit; fi

# UNINSTALL -----------------------------------------------------------------------------------------

if [ "$cmd" == 'uninstall' ]; then

   systemctl stop "$NAME.service"
   systemctl disable "$NAME.service"
   systemctl daemon-reload
   rm -f "$CONFIG_FILE" "$TARGET_JOB_FILE" "$SERVICE_FILE" "$TMP_FILE"
   exit
fi

# CHECKS --------------------------------------------------------------------------------------------

# reset bad timeout input
if [[ ! "$timeout" =~ $NUM_RGX ]]; then

   timeout=''
fi

while [ -z "$disk_label" ] || [[ "$disk_label" =~ $UNSAFE_RGX ]]; do

   if [[ "$disk_label" =~ $UNSAFE_RGX ]]; then

      echo 'Disk label contains not a safe symbols'
   fi

   echo 'Enter disk label: '
   read disk_label
done

while [ "$cmd" == 'set' ] && [[ ! "$timeout" =~ $NUM_RGX ]]; do

   echo 'Enter sleep timeout, in seconds: '
   read timeout
done

# SET DISK ------------------------------------------------------------------------------------------

# set disk
if [ "$cmd" == 'set' ]; then

   # update config (read params, set, write)
   while read line; do

      if [ ! -z "$line" ]; then

         if [[ "$line" =~ $CONFIG_RGX ]]; then

            key=$(echo $line | sed $SED_CUT_CONFIG_KEY)
            val=$(echo $line | sed $SED_CUT_CONFIG_VAL)

            config["$key"]="$val"
         else

            echo "Wrong line in the config:"
            echo "$line"
            clean_exit
         fi
      fi
   done < "$CONFIG_FILE"

   config["$disk_label"]="$timeout"

   cat /dev/null > "$CONFIG_FILE"
   cat /dev/null > "$TMP_FILE"

   for key in "${!config[@]}"; do

      echo "<$key><${config[$key]}>" >> "$TMP_FILE"
   done

   sed '/^$/d' "$TMP_FILE" > "$CONFIG_FILE" # remove empty lines

   # get mount point
   mount_point=$(systemctl list-units -t mount | sed "s/\s\+/|/g" | awk -F '|' '/\.mount/{ print $2 }' | xargs -0 printf %b | grep "$disk_label")

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

   echo "$cmd $disk_label, will sleep after $timeout seconds"
fi

# UNSET DISK ----------------------------------------------------------------------------------------

if [ "$cmd" == 'unset' ]; then

   sed "/$disk_label/d" "$CONFIG_FILE" > "$TMP_FILE"
   mv "$TMP_FILE" "$CONFIG_FILE"

   systemctl enable "$NAME.service"
   systemctl start "$NAME.service"
   systemctl daemon-reload

   echo "$cmd $disk_label"
fi
