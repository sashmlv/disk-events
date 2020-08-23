#!/usr/bin/env bash

ids=()
declare -A labels
declare -A paths
declare -A timeouts
declare -A job_cmds
declare -A fswatch_opts

function read_jobs {

   readonly JOB_RGX='^<[0-9]+><.+><.*><[0-9]+><.+><.*>$' # match job line
   readonly AWK_CUT_JOB_ID='match($0, /^<[0-9]+>/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # id
   readonly AWK_CUT_JOB_LABEL='{ sub(/^<[0-9]+></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # disk label
   readonly AWK_CUT_JOB_PATH='{ sub(/^<[0-9]+><[^>]*></, "" )}; match($0, /^[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # watch path
   readonly AWK_CUT_JOB_TIMEOUT='{ sub(/^<[0-9]+><[^>]*><[^>]*></, "" )}; match($0, /^[0-9]+[^>]*/ ) { str=substr($0, RSTART, RLENGTH); print str }' # job timeout
   readonly AWK_CUT_JOB_COMMAND='{ sub(/^<[0-9]+><[^>]*><[^>]*><[0-9]+></, "" ); sub(/><.*>$/, "" ); print $0 }' # job command
   readonly AWK_CUT_JOB_FSWATCH='match($0, /<[^<]*>$/) { str=substr($0, RSTART, RLENGTH); gsub( /<|>/, "", str ); print str }' # fswatch options

   id=
   label=
   path=
   timeout=
   job_cmd=
   fswatch_opt=

   if [ ! -f "$JOBS_FILE" ]; then

      log '%s: Job file not found\n' "$NAME"
      exit
   fi

   while read line; do

      if [ ! -z "$line" ]; then

         if [[ "$line" =~ $JOB_RGX ]]; then

            id=$(echo "$line" | awk "$AWK_CUT_JOB_ID")
            label=$(echo "$line" | awk "$AWK_CUT_JOB_LABEL")
            path=$(echo "$line" | awk "$AWK_CUT_JOB_PATH")
            timeout=$(echo "$line" | awk "$AWK_CUT_JOB_TIMEOUT")
            job_cmd=$(echo "$line" | awk "$AWK_CUT_JOB_COMMAND")
            fswatch_opt=$(echo "$line" | awk "$AWK_CUT_JOB_FSWATCH")

            ids+=("$id")
            labels["$id"]="$label"
            paths["$id"]="$path"
            timeouts["$id"]="$timeout"
            job_cmds["$id"]="$job_cmd"
            fswatch_opts["$id"]="$fswatch_opt"
         else

            log '%s: Wrong line in the jobs file:\n' "$NAME"
            log '%s: %s\n' "$NAME" "$line"
            exit
         fi
      fi
   done < "$JOBS_FILE"
}

