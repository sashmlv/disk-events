#!/usr/bin/env bash

function job {

   # --- reusable vars ---
   local id=
   local label=
   local path=
   local timeout=
   local throttling=
   local job_cmd=
   local fswatch_opt=
   local dev=
   local sec=
   # -- reusable vars ---

   declare curr_timeout=
   declare key=
   declare val=
   readonly sed_cut_key='s/^<\|>.\+$//g'
   readonly sed_cut_val='s/^<[^>]*><\|>$//g'

   while IFS= read line; do

      key=$(echo "$line" | sed "$sed_cut_key")
      val=$(echo "$line" | sed "$sed_cut_val")

      if [[ "$key" == 'id' ]]; then id="$val";
      elif [[ "$key" == 'label' ]]; then label="$val";
      elif [[ "$key" == 'path' ]]; then path="$val";
      elif [[ "$key" == 'timeout' ]]; then timeout="$val";
      elif [[ "$key" == 'throttling' ]]; then throttling="$val";
      elif [[ "$key" == 'job_cmd' ]]; then command="$val";
      elif [[ "$key" == 'fswatch_opt' ]]; then fswatch_opts="$val";
      elif [[ "$key" == 'dev' ]]; then dev="$val";
      elif [[ "$key" == 'sec' ]]; then sec="$val";
      fi
   done <<< "$1"

   : ${curr_timeout:="$sec"}
   : ${curr_timeout:="$timeout"}
   : ${curr_timeout:="$default_timeout"}

   for i in $(seq "$curr_timeout" -1 1); do

      sleep 1
      echo "<$id><$i>" > $job_fifo &

      log 'job: Job id: %s, seconds: %s, pid: %s\n' "$id" "$i" "${BASHPID}"
   done

   if [[ ! -z "$command" ]]; then

      if [[ -d "${watch_paths[$id]}" ]] || [[ -f "${watch_paths[$id]}" ]]; then

         log 'job: Executing job whith id: %s, and pid: %s\n' "$id" "${BASHPID}"
         echo "<$id><0>" > $job_fifo & # countdown == 0
         eval "$command" | tee -a "$log_file"
      else

         log 'job: Can'\''t execute job whith id: %s, path not found: %s\n' "$id" "${watch_paths[$id]}"
      fi
   fi
}
