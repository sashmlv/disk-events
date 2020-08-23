#!/usr/bin/env bash

readonly NAME='disk-events'
readonly DEFAULT_TIMEOUT=300
readonly BATCH_MARKER='------------'
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly JOBS_FILE="$DIR/tmp/$NAME.jobs"
readonly PID_FILE="$DIR/tmp/$NAME.pid"
readonly JOB_FIFO_PATH="$DIR/tmp/$NAME.job.tmp"
readonly RESTART_FIFO_PATH="$DIR/tmp/$NAME.seconds.tmp"
readonly LOG_FILE="$DIR/tmp/$NAME.log"
LOG=

# CLI ARGUMENTS -------------------------------------------------------------------------------------

cli_log=

if [ ! -z "$*" ]; then

   readonly AWK_CUT_ARG_LOG='match($0, /(--log\ |--log=)[^-]*/) { str=substr($0, RSTART, RLENGTH); gsub( /^(--log\ |--log=)|\ $/, "", str); print str }'

   cli_log=$(echo "$*" | awk "$AWK_CUT_ARG_LOG")

   if [[ ! "$cli_log" =~ ^(true|false)$ ]]; then

      cli_log=
      printf '%s: Bad "--log" value, allowed: true or false\n' "$NAME" | tee -a "$LOG_FILE"
   fi
   LOG="$cli_log"
fi

# FUNCTIONS -----------------------------------------------------------------------------------------

source "${DIR}/lib/log.sh"
source "${DIR}/lib/read_jobs.sh"

read_jobs

if [[ "${#ids[@]}" -eq 0 ]]; then

   log '%s: There are no job data\n' "$NAME"
   exit
fi

log '%s: Read jobs success: %s\n' "$NAME" "$JOBS_FILE"

source "${DIR}/lib/job.sh"

# GET MOUNT POINTS, DEVS, OPTS, ... -----------------------------------------------------------------

source "${DIR}/lib/get_data.sh"

# HANDLE EVENTS -------------------------------------------------------------------------------------

source "${DIR}/lib/events-handler.sh"