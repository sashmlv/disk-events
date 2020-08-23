#!/usr/bin/env bash

function job {

   declare -A args
   local timeout=
   local key=
   local val=

   while IFS= read line; do

      key=$(echo "$line" | sed "$SED_CUT_KEY")
      val=$(echo "$line" | sed "$SED_CUT_VAL")

      if [ "$key" == 'id' ]; then args['id']="$val";
      elif [ "$key" == 'label' ]; then args['label']="$val";
      elif [ "$key" == 'path' ]; then args['path']="$val";
      elif [ "$key" == 'timeout' ]; then args['timeout']="$val";
      elif [ "$key" == 'job_cmd' ]; then args['command']="$val";
      elif [ "$key" == 'fswatch_opt' ]; then args['fswatch_opts']="$val";
      elif [ "$key" == 'dev' ]; then args['dev']="$val";
      elif [ "$key" == 'sec' ]; then
         args['sec']="$val"
         # job_seconds["${args['id']}"]="$val"
      fi
   done <<< "$1"

   : ${timeout:="${args['sec']}"}
   : ${timeout:="${args['timeout']}"}
   : ${timeout:="$DEFAULT_TIMEOUT"}

   for i in $(seq "$timeout" -1 1); do

      sleep 1
      echo "<${args['id']}><$i>" > $JOB_FIFO &

      log '%s: Job id: %s, seconds: %s\n' "$NAME" "${args['id']}" "$i"
   done

   if [ ! -z "${args['command']}" ]; then

      if [ -d "${watch_paths[${args['id']}]}" ] || [ -f "${watch_paths[${args['id']}]}" ]; then

         log '%s: Executing job whith id: %s\n' "$NAME" "${args['id']}"
         eval "${args['command']}" | tee -a "$LOG_FILE"
      else

         log '%s: Can'\''t execute job whith id: %s, path not found: %s\n' "$NAME" "${args['id']}" "${watch_paths[${args['id']}]}"
      fi
   fi
}
