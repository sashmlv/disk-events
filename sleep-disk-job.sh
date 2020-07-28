#!/bin/bash

declare -A config
declare -A devs
declare -A sleep_pids
declare -A timeouts
cmd=$1
data=$2
key=
value=
mount=
mounts=()
current_disk=
last_disk=
data_lines=
NAME='sleep-disk'
BATCH_MARKER='------------'
CONFIG_RGX='^<.+><[0-9]+>$' # match config line
CONFIG_FILE="/home/$USER/bin/$NAME.conf"
PID_FILE="/home/$USER/bin/$NAME.pid"
SED_CUT_CONFIG_KEY='s/^\(<\)\|\(><.\+>\)$//g' # cut key from config line
SED_CUT_CONFIG_VAL='s/^\(<.\+><\)\|\(>\)$//g' # cut val from config line
SED_CUT_DEV='s/^PKNAME="\|"\sLABEL.\+//g' # cut dev
SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount

# close previous process
PREVIOUS_PID=$(cat "$PID_FILE")
kill "$PREVIOUS_PID" 2>/dev/null;
echo $$ >> "$PID_FILE"

# INITIAL DATA --------------------------------------------------------------------------------------

if [ "$command" == 'data' ]; then

   readarray -t data_lines <<< $(echo "$data" | sed 's/<>/\n/g');

   for line in "${data_lines[@]}"; do

      key=$(echo "$line" | sed "$SED_CUT_CONFIG_KEY")
      val=$(echo "$line" | sed "$SED_CUT_CONFIG_VAL")

      timeouts[$key]=$val
   done
fi

# CONFIG --------------------------------------------------------------------------------------------

# check config file
if [ ! -f "$CONFIG_FILE" ]; then

   echo "Config file not found"
   exit
fi

# read config
while read line; do

   if [ ! -z "$line" ]; then

      if [[ "$line" =~ $CONFIG_RGX ]]; then

         key=$(echo "$line" | sed "$SED_CUT_CONFIG_KEY")
         val=$(echo "$line" | sed "$SED_CUT_CONFIG_VAL")

         config["$key"]="$val"
      else

         echo "Wrong line in the config:"
         echo "$line"
         exit
      fi
   fi
done < "$CONFIG_FILE"

if [[ ${#config[*]} -eq 0 ]]; then

   echo "Config file empty"
   exit
fi

# GET MOUNT POINTS, GET DEV -------------------------------------------------------------------------

while read line; do

   for disk_label in "${!config[@]}"; do

      if [[ "$line" =~ "$disk_label" ]]; then

         devs["$disk_label"]=$(echo "$line" | sed "$SED_CUT_DEV")
         mount=$(echo "$line" | sed "$SED_CUT_MOUNT")
         mounts+=("$mount")
      fi
   done
done <<< $(lsblk -Ppo pkname,label,mountpoint)

# JOB -----------------------------------------------------------------------------------------------

# watch disk access events in coprocess
coproc (

   while read access_path; do

      for disk_label in "${!config[@]}"; do

         if [[ "$access_path" =~ "$disk_label" ]]; then

            current_disk="$disk_label"
         fi
      done

      if [ "$access_path" == "$BATCH_MARKER" ]; then

         echo "$current_disk"
      fi
   done < <(fswatch --batch-marker="$BATCH_MARKER" "${mounts[@]}")
)

function just_do_sleep {

   sleep 10
   echo "sleep $1"
}

# read and handle access events data
while read -u ${COPROC[0]}; do

   last_disk=$REPLY
   # kill "${sleep_pids[$last_disk]}" 2>/dev/null;
   # just_do_sleep "$last_disk" &
   # sleep_pids[$last_disk]=$!
   echo $last_disk
   # echo "${sleep_pids[$last_disk]}"
done
