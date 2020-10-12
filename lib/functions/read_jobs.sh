#!/usr/bin/env bash

ids=()
declare -A labels
declare -A paths
declare -A timeouts
declare -A job_cmds
declare -A fswatch_opts

function read_jobs {

   readonly job_rgx='^<[0-9]+><.+><.*><[0-9]+><.+><.*>$' # match job line
   readonly awk_cut_job_id='match($0, /^<[0-9]+>/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # id
   readonly awk_cut_job_label='{ sub(/^<[0-9]+></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # disk label
   readonly awk_cut_job_path='{ sub(/^<[0-9]+><[^>]*></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # watch path
   readonly awk_cut_job_timeout='{ sub(/^<[0-9]+><[^>]*><[^>]*></, "" )}; match($0, /^[0-9]+[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # job timeout
   readonly awk_cut_job_command='{ sub(/^<[0-9]+><[^>]*><[^>]*><[0-9]+></, "" ); sub(/><.*>$/, "" ); print $0 }' # job command
   readonly awk_cut_job_fswatch='match($0, /<[^<]*>$/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # fswatch options

   id=
   label=
   path=
   timeout=
   job_cmd=
   fswatch_opt=

   if [[ ! -f "$jobs_file" ]]; then

      log '%s: Job file not found\n' "$name"
      exit
   fi

   while read line; do

      if [[ ! -z "$line" ]]; then

         if [[ "$line" =~ $job_rgx ]]; then

            id=$(echo "$line" | awk "$awk_cut_job_id")
            label=$(echo "$line" | awk "$awk_cut_job_label")
            path=$(echo "$line" | awk "$awk_cut_job_path")
            timeout=$(echo "$line" | awk "$awk_cut_job_timeout")
            job_cmd=$(echo "$line" | awk "$awk_cut_job_command")
            fswatch_opt=$(echo "$line" | awk "$awk_cut_job_fswatch")

            ids+=("$id")
            labels["$id"]="$label"
            paths["$id"]="$path"
            timeouts["$id"]="$timeout"
            job_cmds["$id"]="$job_cmd"
            fswatch_opts["$id"]="$fswatch_opt"
         else

            log '%s: Wrong line in the jobs file:\n' "$name"
            log '%s: %s\n' "$name" "$line"
            exit
         fi
      fi
   done < "$jobs_file"
}
