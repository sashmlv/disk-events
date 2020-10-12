#!/usr/bin/env bash

# executing on mount/umount disks

readonly name='disk-events'
readonly default_timeout=300
readonly batch_marker='------------'
readonly dir="$( cd "$( dirname "${bash_source[0]}" )" >/dev/null 2>&1 && pwd )"
readonly jobs_file="${dir}/tmp/$name.jobs"
readonly pid_file="${dir}/tmp/$name.pid"
readonly job_fifo_path="${dir}/tmp/$name.job.tmp"
readonly restart_fifo_path="${dir}/tmp/$name.seconds.tmp"
readonly log_file="${dir}/tmp/$name.log"

# CLI ARGUMENTS -------------------------------------------------------------------------------------

logger= # for log.sh

if [[ ! -z "$*" ]]; then

   readonly awk_cut_arg_log='match($0, /(--logger\ |--logger=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--logger\ |--logger=)|\ $/, "", str); print str }'

   logger=$(echo "$*" | awk "$awk_cut_arg_log")

   if [[ ! "$logger" =~ ^(true|false)$ ]]; then

      logger=
      printf '%s: Bad "--logger" value, allowed: true or false\n' "$name" | tee -a "$log_file"
   fi
fi

# FUNCTIONS -----------------------------------------------------------------------------------------

source "${dir}/lib/functions/log.sh"
source "${dir}/lib/functions/read-jobs.sh"

read_jobs

if [[ "${#ids[@]}" -eq 0 ]]; then

   log '%s: There are no job data\n' "$name"
   exit
fi

log '%s: Read jobs success: %s\n' "$name" "$jobs_file"

source "${dir}/lib/job/job.sh"

# GET MOUNT POINTS, DEVS, OPTS, ... -----------------------------------------------------------------

source "${dir}/lib/job/get-data.sh"

# HANDLE EVENTS -------------------------------------------------------------------------------------

source "${dir}/lib/job/events-handler.sh"