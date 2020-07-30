#!/bin/bash

declare -A config
declare -A devs
declare -A sleep_pids
declare -A sleep_seconds
declare -A timeouts
cmd=$1
data=$2
key=
value=
mount=
mounts=()
disk_labels=()
current_disk=
last_disk=
data_lines=
NAME='sleep-disk'
BATCH_MARKER='------------'
CONFIG_RGX='^<.+><[0-9]+>$' # match config line
CONFIG_FILE="/home/$USER/bin/$NAME.conf"
PID_FILE="/tmp/$NAME.pid"
SED_CUT_KEY='s/^\(<\)\|\(><.\+>\)$//g' # cut key from config line
SED_CUT_VAL='s/^\(<.\+><\)\|\(>\)$//g' # cut val from config line
SED_CUT_DEV='s/^PKNAME="\|"\sLABEL.\+//g' # cut dev
SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount
JOB_FIFO_PATH="/tmp/$NAME.job.tmp"
RESET_FIFO_PATH="/tmp/$NAME.seconds.tmp"

# CHECK SCRIPT INSTANCE -----------------------------------------------------------------------------

# replace this process with new other one with params
if pidof -o %PPID -x "$(basename $0)" >/dev/null; then

   JOB_FIFO=$JOB_FIFO_PATH
   RESET_FIFO=$RESET_FIFO_PATH

   exec 3<>$RESET_FIFO

   echo 'restart' > $JOB_FIFO

   while read -t 0.01 line <& 3; do

      echo "---> $line"
   done

   PREVIOUS_PID=$(cat 2>/dev/null "$PID_FILE")
   kill -- -"$PREVIOUS_PID"
fi

rm -f $JOB_FIFO_PATH
JOB_FIFO=$JOB_FIFO_PATH
mkfifo -m 600 "$JOB_FIFO"

rm -f $RESET_FIFO_PATH
RESET_FIFO=$RESET_FIFO_PATH
mkfifo -m 600 "$RESET_FIFO"

echo "$$" > "$PID_FILE"
echo "$$"

# INITIAL DATA --------------------------------------------------------------------------------------

# if [ "$cmd" == 'data' ]; then

#    readarray -t data_lines <<< $(echo "$data" | sed 's/<>/\n/g');

#    for line in "${data_lines[@]}"; do

#       key=$(echo "$line" | sed "$SED_CUT_KEY")
#       val=$(echo "$line" | sed "$SED_CUT_VAL")

#       timeouts[$key]=$val
#    done
# fi

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

         key=$(echo "$line" | sed "$SED_CUT_KEY")
         val=$(echo "$line" | sed "$SED_CUT_VAL")

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

      disk_labels+=("$disk_label")

      if [[ "$line" =~ "$disk_label" ]]; then

         devs["$disk_label"]=$(echo "$line" | sed "$SED_CUT_DEV")
         mount=$(echo "$line" | sed "$SED_CUT_MOUNT")
         mounts+=("$mount")
      fi
   done
done <<< $(lsblk -Ppo pkname,label,mountpoint)

# JOB -----------------------------------------------------------------------------------------------

# watch disk access events
while read access_path; do

   for disk_label in "${!config[@]}"; do

      if [[ "$access_path" =~ "$disk_label" ]]; then

         current_disk="$disk_label"
      fi
   done

   if [ "$access_path" == "$BATCH_MARKER" ]; then

      echo "$current_disk" > $JOB_FIFO
   fi
done < <(fswatch --batch-marker="$BATCH_MARKER" "${mounts[@]}") &

function just_do_sleep {

   for i in {60..1}; do

      echo "<$1><$i>" > $JOB_FIFO
      sleep 1
   done

   echo "move $1 into sleep mode"
}

# read and handle access events data
while read line < $JOB_FIFO; do

   echo "$line"

   if [[ " ${disk_labels[@]} " =~ " ${line} " ]]; then

      last_disk=$line
      kill "${sleep_pids[$last_disk]}" 2>/dev/null;
      just_do_sleep "$last_disk" &
      sleep_pids[$last_disk]=$!

   elif [ "$line" == 'restart' ]; then

      for disk_label in "${!sleep_seconds[@]}"; do

         echo "<$disk_label><${sleep_seconds[$disk_label]}>" > $RESET_FIFO
      done
   else

      # remember current timers state
      key=$(echo "$line" | sed "$SED_CUT_KEY")
      val=$(echo "$line" | sed "$SED_CUT_VAL")
      sleep_seconds[$key]=$val
   fi
done
