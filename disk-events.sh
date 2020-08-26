#!/usr/bin/env bash

# CLI FORMAT: sudo ./disk-events.sh set --label=<disk label> --path=<path> --timeout=<timeout> --command=<command> --fswatch=<fswatch options>

set -o errexit
set -o pipefail
set -o nounset
# [[ "${DEBUG}" == 'true' ]] && set -o xtrace

readonly NAME='disk-events'
readonly DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly JOB_FILE="$DIR/lib/$NAME-job.sh"
readonly JOBS_FILE="./tmp/$NAME.jobs"
readonly TMP_FILE="./tmp/$NAME.tmp"
readonly SERVICE_FILE="/etc/systemd/system/$NAME.service"
readonly LOG_FILE="$DIR/tmp/$NAME.log"
LOG=

source "${DIR}/lib/log.sh"

# CHECK UTILS ---------------------------------------------------------------------------------------

if [ ! -x "$(command -v fswatch)" ]; then

   printf '"fswatch" not found, please install "fswatch"\n'
   exit
fi

# LOAD LIB ------------------------------------------------------------------------------------------

source "${DIR}/lib/read_jobs.sh"
source "${DIR}/lib/print_jobs.sh"

# CLI ARGUMENTS -------------------------------------------------------------------------------------

source "${DIR}/lib/cli_arguments.sh"

# COMMAND -------------------------------------------------------------------------------------------

COMMANDS=('set' 'unset' 'print' 'uninstall' 'quit')

if [ -z "$cli_cmd" ] || [[ ! " ${COMMANDS[@]} " =~ " ${cli_cmd} " ]]; then

   echo 'Select command: '
   echo '1. set disk'
   echo '2. unset disk'
   echo '3. print jobs'
   echo '4. uninstall'
   echo '5. quit'
   read cli_cmd
   case "$cli_cmd" in
      1) cli_cmd='set';;
      2) cli_cmd='unset';;
      3) cli_cmd='print';;
      4) cli_cmd='uninstall';;
      5) cli_cmd='quit';;
      *)
         echo "Invalid option $cli_cmd"
         exit
         ;;
   esac
fi

# QUIT ----------------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'quit' ]; then printf '%s' "$cli_cmd"; exit; fi

# UNINSTALL -----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'uninstall' ]; then

   systemctl stop "$NAME.service"
   systemctl disable "$NAME.service"
   systemctl daemon-reload
   rm -f "$SERVICE_FILE"
   exit
fi

# PRINT JOBS ----------------------------------------------------------------------------------------

if [ "$cli_cmd" == 'print' ]; then

   print_jobs
   exit
fi

# INSTALL -------------------------------------------------------------------------------------------

source "${DIR}/lib/install.sh"

# SET RECORD ----------------------------------------------------------------------------------------

source "${DIR}/lib/set.sh"

# UNSET RECORD --------------------------------------------------------------------------------------

source "${DIR}/lib/unset.sh"