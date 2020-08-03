#!/bin/bash

NAME='sleep-disk'
DEFAULT_TIMEOUT=180
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

declare -A config
declare -A devs
declare -A sleep_pids
declare -A sleep_seconds
declare -A timeouts

key=
value=
mount=
mounts=()
labels=()
data_lines=()
current_disk=
last_disk=
tmpstr=

# CHECK SCRIPT INSTANCE -----------------------------------------------------------------------------

# replace this process with new other one with params
if pidof -o %PPID -x "$(basename $0)" >/dev/null; then

   JOB_FIFO=$JOB_FIFO_PATH
   RESET_FIFO=$RESET_FIFO_PATH

   exec 3<>$RESET_FIFO

   echo 'restart' > $JOB_FIFO &

   # remember previous timers state
   while read -t 0.01 line <& 3; do tmpstr="$line"; done

   IFS=$'\n';
   data_lines=($(echo "$tmpstr" | sed 's/<>/\n/g'))

   for line in "${data_lines[@]}"; do

      key=$(echo "$line" | sed "$SED_CUT_KEY")
      val=$(echo "$line" | sed "$SED_CUT_VAL")

      sleep_seconds["$key"]="$val"
   done

   PREVIOUS_PID=$(cat 2>/dev/null "$PID_FILE")
   kill -- -"$PREVIOUS_PID"
   tmpstr=''
fi

rm -f $JOB_FIFO_PATH
JOB_FIFO=$JOB_FIFO_PATH
mkfifo -m 600 "$JOB_FIFO"

rm -f $RESET_FIFO_PATH
RESET_FIFO=$RESET_FIFO_PATH
mkfifo -m 600 "$RESET_FIFO"

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

   for label in "${!config[@]}"; do

      if [[ ! " ${labels[@]} " =~ " ${label} " ]]; then

         labels+=("$label")
      fi

      if [[ "$line" =~ "$label" ]]; then

         devs["$label"]=$(echo "$line" | sed "$SED_CUT_DEV")
         mount=$(echo "$line" | sed "$SED_CUT_MOUNT")
         mounts+=("$mount")
      fi
   done
done < <(lsblk -Ppo pkname,label,mountpoint)

# START PREVIOUS JOB IF EXISTS ----------------------------------------------------------------------

function just_do_sleep {

   for i in $(seq "${2:-$DEFAULT_TIMEOUT}" -1 1); do

      sleep 1
      echo "<$1><$i>" > $JOB_FIFO &
   done

   if [ ! -z "${devs[$1]}" ]; then

      echo "move $1 ${devs[$1]} into sleep mode"
      sdparm --readonly --command=stop "${devs[$1]}"
   fi
}

# keep previous process if has data
for label in "${!sleep_seconds[@]}"; do

   just_do_sleep "$label" "${sleep_seconds[$label]}" &
done

echo "$$" > "$PID_FILE"
echo "$$"

# JOB -----------------------------------------------------------------------------------------------

# watch disk access events
while read access_path; do

   for label in "${!config[@]}"; do

      if [[ "$access_path" =~ "$label" ]]; then

         current_disk="$label"
      fi
   done

   if [ "$access_path" == "$BATCH_MARKER" ]; then

      echo "$current_disk" > $JOB_FIFO &
   fi
done < <(fswatch --batch-marker="$BATCH_MARKER" "${mounts[@]}") &

# read and handle access events data
while read line < $JOB_FIFO; do

   echo "$line"

   if [[ " ${labels[@]} " =~ " ${line} " ]]; then

      last_disk=$line
      kill "${sleep_pids[$last_disk]}" 2>/dev/null;
      just_do_sleep "$last_disk" "${config[$last_disk]}" &
      sleep_pids[$last_disk]=$!

   elif [ "$line" == 'restart' ]; then

      for label in "${!sleep_seconds[@]}"; do

         tmpstr+="<$label><${sleep_seconds[$label]}><>"
      done

      echo "$tmpstr" > $RESET_FIFO &
      tmpstr=''
   else

      # remember current timers state
      key=$(echo "$line" | sed "$SED_CUT_KEY")
      val=$(echo "$line" | sed "$SED_CUT_VAL")
      sleep_seconds["$key"]="$val"
   fi
done
