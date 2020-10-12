#!/usr/bin/env bash

function job {

   declare -A args
   declare timeout=
   declare key=
   declare val=

   while IFS= read line; do

      key=$(echo "$line" | sed "$sed_cut_key")
      val=$(echo "$line" | sed "$sed_cut_val")

      if [[ "$key" == 'id' ]]; then args['id']="$val";
      elif [[ "$key" == 'label' ]]; then args['label']="$val";
      elif [[ "$key" == 'path' ]]; then args['path']="$val";
      elif [[ "$key" == 'timeout' ]]; then args['timeout']="$val";
      elif [[ "$key" == 'job_cmd' ]]; then args['command']="$val";
      elif [[ "$key" == 'fswatch_opt' ]]; then args['fswatch_opts']="$val";
      elif [[ "$key" == 'dev' ]]; then args['dev']="$val";
      elif [[ "$key" == 'sec' ]]; then args['sec']="$val";
      fi
   done <<< "$1"

   : ${timeout:="${args['sec']}"}
   : ${timeout:="${args['timeout']}"}
   : ${timeout:="$default_timeout"}

   for i in $(seq "$timeout" -1 1); do

      sleep 1
      echo "<${args['id']}><$i>" > $job_fifo &

      log 'job: Job id: %s, seconds: %s\n' "${args['id']}" "$i"
   done

   if [[ ! -z "${args['command']}" ]]; then

      if [[ -d "${watch_paths[${args['id']}]}" ]] || [[ -f "${watch_paths[${args['id']}]}" ]]; then

         log 'job: Executing job whith id: %s\n' "${args['id']}"
         echo "<${args['id']}><0>" > $job_fifo & # countdown == 0
         eval "${args['command']}" | tee -a "$log_file"
      else

         log 'job: Can'\''t execute job whith id: %s, path not found: %s\n' "${args['id']}" "${watch_paths[${args['id']}]}"
      fi
   fi
}
