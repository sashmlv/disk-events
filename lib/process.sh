#!/usr/bin/env bash

readonly name='disk-events'
readonly default_timeout=300
readonly batch_marker='------------'
readonly dir="$( cd "$( dirname "${bash_source[0]}" )" >/dev/null 2>&1 && pwd )"
readonly jobs_file="$dir/tmp/$name.jobs"
readonly pid_file="$dir/tmp/$name.pid"
readonly job_fifo_path="$dir/tmp/$name.job.tmp"
readonly restart_fifo_path="$dir/tmp/$name.seconds.tmp"
readonly log_file="$dir/tmp/$name.log"
log=

# CLI ARGUMENTS -------------------------------------------------------------------------------------

cli_log=

if [[ ! -z "$*" ]]; then

   readonly awk_cut_arg_log='match($0, /(--log\ |--log=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--log\ |--log=)|\ $/, "", str); print str }'

   cli_log=$(echo "$*" | awk "$awk_cut_arg_log")

   if [[ ! "$cli_log" =~ ^(true|false)$ ]]; then

      cli_log=
      printf '%s: Bad "--log" value, allowed: true or false\n' "$name" | tee -a "$log_file"
   fi
   LOG="$cli_log"
fi

# FUNCTIONS -----------------------------------------------------------------------------------------

source "${dir}/lib/log.sh"
source "${dir}/lib/read_jobs.sh"

read_jobs

if [[ "${#ids[@]}" -eq 0 ]]; then

   log '%s: There are no job data\n' "$name"
   exit
fi

log '%s: Read jobs success: %s\n' "$name" "$jobs_file"

source "${dir}/lib/job.sh"

# GET MOUNT POINTS, DEVS, OPTS, ... -----------------------------------------------------------------

source "${dir}/lib/get_data.sh"

# HANDLE EVENTS -------------------------------------------------------------------------------------

source "${dir}/lib/events_handler.sh"