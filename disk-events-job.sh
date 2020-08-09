#!/bin/bash

NAME='disk-events'
DEFAULT_TIMEOUT=300
BATCH_MARKER='------------'
CONFIG_RGX='^<.+><[0-9]+><.+>$' # match config line
CONFIG_FILE="/home/$USER/bin/$NAME.conf"
PID_FILE="/tmp/$NAME.pid"
JOB_FIFO_PATH="/tmp/$NAME.job.tmp"
RESET_FIFO_PATH="/tmp/$NAME.seconds.tmp"

# FUNCTIONS -----------------------------------------------------------------------------------------

ids=()
declare -A labels
declare -A paths
declare -A timeouts
declare -A job_cmds
declare -A fswatch_opts

function read_config {

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

            printf 'Wrong line in the config:\n'
            printf "$line"
            exit
         fi
      fi
   done < "$CONFIG_FILE"

   if [[ "${#ids[@]}" -eq 0 ]]; then

      printf 'There are no config data'
      exit
   fi
}

function job {

   local id=
   local label=
   local path=
   local timeout=
   local job_cmd=
   local fswatch_opt=
   local dev=
   local sec=

   while IFS= read line; do

      key=$(echo "$line" | sed "$SED_CUT_KEY")
      val=$(echo "$line" | sed "$SED_CUT_VAL")

      if [ "$key" == 'id' ]; then id="$val";
      elif [ "$key" == 'label' ]; then label="$val";
      elif [ "$key" == 'path' ]; then path="$val";
      elif [ "$key" == 'timeout' ]; then timeout="$val";
      elif [ "$key" == 'job_cmd' ]; then job_cmd="$val";
      elif [ "$key" == 'fswatch_opt' ]; then fswatch_opt="$val";
      elif [ "$key" == 'dev' ]; then dev="$val";
      elif [ "$key" == 'sec' ]; then
         sec="$val"
         job_seconds["$id"]="$sec"
      fi
   done <<< "$1"

   for i in $(seq "${timeout:-$DEFAULT_TIMEOUT}" -1 1); do

      sleep 1
      echo "<$id><$i>" > $JOB_FIFO &
   done

   if [ ! -z "$job_cmd" ]; then

      echo "Executing $id job"
      # $("$job_cmd" "$id" "$label" "$path" "$timeout" "$job_cmd" "$fswatch_opt" "$dev")
   fi
}

# GET MOUNT POINTS, DEVS, OPTS, ... -----------------------------------------------------------------

read_config

declare -A devs
declare -A watch_paths
watch_opts=()
mount_point=
path=

SED_CUT_DEV='s/^PKNAME="\|"\sLABEL.\+//g' # cut dev
SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount

while read line; do

   for id in "${ids[@]}"; do

      if [[ "$line" =~ "${labels[$id]}" ]]; then

         devs["$id"]=$(echo "$line" | sed "$SED_CUT_DEV")
         mount_point=$(echo "$line" | sed "$SED_CUT_MOUNT")
         path=$(echo "${paths[$id]}" | sed 's/^\(\.\/\|\/\)//')


         if [ ! -z "$path" ]; then

            watch_path="$mount_point/$path"
         else

            watch_path="$mount_point"
         fi

         if [ ! -z "$watch_path" ] && { [ -d "$watch_path" ] || [ -f "$watch_path" ]; }; then

            watch_paths["$id"]="$watch_path"
            watch_opts+=("${fswatch_opts[$id]}")
         fi
      fi
   done
done < <(lsblk -Ppo pkname,label,mountpoint)

if [[ "${#watch_paths[@]}" -eq 0 ]]; then

   printf 'No path found for watching'
   exit
fi

# CHECK SCRIPT INSTANCE -----------------------------------------------------------------------------

SED_CUT_KEY='s/^<\|><[^>]*>$//g'
SED_CUT_VAL='s/^<[^>]*><\|>$//g'
declare -A job_seconds
data_lines=()
tmpstr=

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

      id=$(echo "$line" | sed "$SED_CUT_KEY")
      sec=$(echo "$line" | sed "$SED_CUT_VAL")

      job_seconds["$id"]="$sec"
   done

   PREVIOUS_PID=$(cat 2>/dev/null "$PID_FILE")
   kill -- -"$PREVIOUS_PID"
   tmpstr=''
fi

# START PREVIOUS JOB IF EXISTS ----------------------------------------------------------------------

# keep previous process if have data
for id in "${!job_seconds[@]}"; do

   job "<id><$id>
<label><${labels[$id]}>
<path><${paths[$id]}>
<timeout><${timeouts[$id]}>
<job_cmd><${job_cmds[$id]}>
<fswatch_opt><${fswatch_opts[$id]}>
<dev><${devs[$id]}>
<sec><${job_seconds[$id]}><" &
done

rm -f $JOB_FIFO_PATH
JOB_FIFO=$JOB_FIFO_PATH
mkfifo -m 600 "$JOB_FIFO"

rm -f $RESET_FIFO_PATH
RESET_FIFO=$RESET_FIFO_PATH
mkfifo -m 600 "$RESET_FIFO"

echo "$$" > "$PID_FILE"
echo "$$"

# JOB -----------------------------------------------------------------------------------------------

current_id=

# watch disk access events, and write them
while read access_path; do

   # echo "$access_path"

   for id in "${!watch_paths[@]}"; do

      if [[ "$access_path" =~ "${watch_paths[$id]}" ]]; then

         current_id="$id"
      fi
   done

   if [ "$access_path" == "$BATCH_MARKER" ]; then

      echo "$current_id" > $JOB_FIFO &
   fi
# done < <(fswatch --format="<%p><%f>" --event-flag-separator="," --batch-marker="$BATCH_MARKER" "${watch_opts[@]}" "${watch_paths[@]}") &
done < <(fswatch --batch-marker="$BATCH_MARKER" "${watch_opts[@]}" "${watch_paths[@]}") &

declare -A job_pids
id=
sec=

# read and handle access events data
while read line < $JOB_FIFO; do

   if [[ " ${!watch_paths[@]} " =~ " ${line} " ]]; then

      id="$line"
      kill "${job_pids[$id]}" 2>/dev/null;
      job "<id><$id>
<label><${labels[$id]}>
<path><${paths[$id]}>
<timeout><${timeouts[$id]}>
<job_cmd><${job_cmds[$id]}>
<fswatch_opt><${fswatch_opts[$id]}>
<dev><${devs[$id]}>" &
      job_pids["$id"]="$!"

   elif [ "$line" == 'restart' ]; then

      for id in "${!job_seconds[@]}"; do

         tmpstr+="<$id><${job_seconds[$id]}><>"
      done

      echo "$tmpstr" > $RESET_FIFO &
      tmpstr=''
   else

      # remember current timers state
      id=$(echo "$line" | sed "$SED_CUT_KEY")
      sec=$(echo "$line" | sed "$SED_CUT_VAL")
      job_seconds["$id"]="$sec"
   fi
done
