#!/usr/bin/env bash

# CHECK SCRIPT INSTANCE -----------------------------------------------------------------------------

readonly SED_CUT_KEY='s/^<\|>.\+$//g'
readonly SED_CUT_VAL='s/^<[^>]*><\|>$//g'
declare -A job_seconds
data_lines=()
tmpstr=

# replace this process with new other one with params
if pidof -o %PPID -x "$(basename $0)" >/dev/null; then

   JOB_FIFO=$JOB_FIFO_PATH
   RESTART_FIFO=$RESTART_FIFO_PATH

   exec 3<>$RESTART_FIFO

   echo 'restart' > $JOB_FIFO &

   log '%s: Starting previous jobs\n' "$NAME"

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

   log '%s: Previous jobs started\n' "$NAME"
fi

# START PREVIOUS JOBS IF EXISTS ---------------------------------------------------------------------

# keep previous process if have data
for id in "${!job_seconds[@]}"; do

   job "<id><$id>
<label><${labels[$id]}>
<path><${paths[$id]}>
<timeout><${timeouts[$id]}>
<job_cmd><${job_cmds[$id]}>
<fswatch_opt><${fswatch_opts[$id]}>
<dev><${devs[$id]}>
<sec><${job_seconds[$id]}>" &
done

rm -f $JOB_FIFO_PATH
JOB_FIFO=$JOB_FIFO_PATH
mkfifo -m 600 "$JOB_FIFO"

rm -f $RESTART_FIFO_PATH
RESTART_FIFO=$RESTART_FIFO_PATH
mkfifo -m 600 "$RESTART_FIFO"

echo "$$" > "$PID_FILE"

log '%s: Running process with PID: %s\n' "$NAME" "$$"

# JOB -----------------------------------------------------------------------------------------------

current_id=

# watch disk access events, and write them
while read access_path; do

   for id in "${!watch_paths[@]}"; do

      if [[ "$access_path" =~ "${watch_paths[$id]}" ]]; then

         current_id="$id"
      fi
   done

   if [ "$access_path" == "$BATCH_MARKER" ]; then

      echo "$current_id" > $JOB_FIFO &

      log '%s: Event for id: %s\n' "$NAME" "$id"
   fi
done < <(fswatch --batch-marker="$BATCH_MARKER" "${watch_opts[@]}" "${watch_paths[@]}") &

log "%s: %s\n" "$NAME" "Watching: $(echo ${watch_paths[@]})"

declare -A job_pids
id=
sec=

# read and handle access events data
while read line < $JOB_FIFO; do

   if [[ " ${!watch_paths[@]} " =~ " ${line} " ]]; then # reset timers after path thouch

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

      echo "$tmpstr" > $RESTART_FIFO &
      tmpstr=''
   else

      # remember current timers state
      id=$(echo "$line" | sed "$SED_CUT_KEY")
      sec=$(echo "$line" | sed "$SED_CUT_VAL")
      job_seconds["$id"]="$sec"
   fi
done &
