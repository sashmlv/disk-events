#!/usr/bin/env bash

# executing only on mount disks

# CHECK SCRIPT INSTANCE -----------------------------------------------------------------------------

readonly sed_cut_key='s/^<\|>.\+$//g'
readonly sed_cut_val='s/^<[^>]*><\|>$//g'
declare -A job_seconds
data_lines=()
tmpstr=

previous_pid=$(cat 2>/dev/null "$pid_file")
echo "$$" > "$pid_file"
log 'events-handler: Running process with PID: %s\n' "$$"

# replace this process with new other one with params
if kill -0 -"$previous_pid" 2>/dev/null; then

   job_fifo=$job_fifo_path
   restart_fifo=$restart_fifo_path

   exec 3<>$restart_fifo

   echo 'restart' > $job_fifo &

   log 'events-handler: Starting previous jobs\n'

   # remember previous timers state
   while read -t 0.01 line <& 3; do tmpstr="$line"; done

   IFS=$'\n';
   data_lines=($(echo "$tmpstr" | sed 's/<>/\n/g'))

   for line in "${data_lines[@]}"; do

      id=$(echo "$line" | sed "$sed_cut_key")
      sec=$(echo "$line" | sed "$sed_cut_val")

      job_seconds["$id"]="$sec"
   done

   kill -- -"$previous_pid"
   tmpstr=''

   log 'events-handler: Previous jobs started\n'
fi

# START PREVIOUS JOBS IF EXISTS ---------------------------------------------------------------------

# keep previous process if we have data and seconds not 0
for id in "${!job_seconds[@]}"; do

   if [[ "${job_seconds[$id]}" != "0" ]]; then

      job "<id><$id>
<label><${labels[$id]}>
<path><${paths[$id]}>
<timeout><${timeouts[$id]}>
<job_cmd><${job_cmds[$id]}>
<fswatch_opt><${fswatch_opts[$id]}>
<dev><${devs[$id]}>
<sec><${job_seconds[$id]}>" &
   fi
done

rm -f $job_fifo_path
job_fifo=$job_fifo_path
mkfifo -m 600 "$job_fifo"

rm -f $restart_fifo_path
restart_fifo=$restart_fifo_path
mkfifo -m 600 "$restart_fifo"

# JOB -----------------------------------------------------------------------------------------------

current_id=

# watch disk access events, and write them
while read access_path; do

   for id in "${!watch_paths[@]}"; do

      if [[ "$access_path" =~ "${watch_paths[$id]}" ]]; then

         current_id="$id"
      fi
   done

   if [[ "$access_path" == "$batch_marker" ]]; then

      echo "$current_id" > $job_fifo &
      log 'events-handler: Event for id: %s\n' "$id"
   fi
done < <(fswatch --batch-marker="$batch_marker" "${watch_opts[@]}" "${watch_paths[@]}") &

log "events-handler: %s\n" "Watching: $(echo ${watch_paths[@]})"

declare -A job_pids
id=
sec=

# read and handle access events data
while read line < $job_fifo; do

   if [[ " ${!watch_paths[@]} " =~ " ${line} " ]]; then # reset timers after path thouch

      id="$line"
      kill "${job_pids[$id]}" 2>/dev/null
      log "events-handler: Killed process for job: %s, with pid: %s\n" "$id" "${job_pids[$id]}"
      job "<id><$id>
<label><${labels[$id]}>
<path><${paths[$id]}>
<timeout><${timeouts[$id]}>
<job_cmd><${job_cmds[$id]}>
<fswatch_opt><${fswatch_opts[$id]}>
<dev><${devs[$id]}>" &
      job_pids["$id"]="$!"

   elif [[ "$line" == 'restart' ]]; then

      for id in "${!job_seconds[@]}"; do

         tmpstr+="<$id><${job_seconds[$id]}><>"
      done

      echo "$tmpstr" > $restart_fifo &
      tmpstr=''
   else

      # remember current timers state
      id=$(echo "$line" | sed "$sed_cut_key")
      sec=$(echo "$line" | sed "$sed_cut_val")
      job_seconds["$id"]="$sec"
   fi
done &
