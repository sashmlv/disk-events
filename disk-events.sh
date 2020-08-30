#!/usr/bin/env bash

# CLI FORMAT: sudo ./disk-events.sh set --label=<disk label> --path=<path> --timeout=<timeout> --command=<command> --fswatch=<fswatch options>

set -o errexit
set -o pipefail
set -o nounset
# [[ "${debug}" == 'true' ]] && set -o xtrace

readonly name='disk-events'
readonly dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly process_file="$dir/lib/process.sh"
readonly jobs_file="./tmp/$name.jobs"
readonly tmp_file="./tmp/$name.tmp"
readonly service_file="/etc/systemd/system/$name.service"
readonly log_file="$dir/tmp/$name.log"
log=true

source "${dir}/lib/log.sh"
source "${dir}/lib/install.sh"

if [[ ! -x "$(command -v fswatch)" ]]; then

   log '"fswatch" not found, please install "fswatch"\n'
   exit
fi

source "${dir}/lib/validate.sh"
source "${dir}/lib/cli_arguments.sh"
source "${dir}/lib/read_jobs.sh"
source "${dir}/lib/print_jobs.sh"
source "${dir}/lib/get_mount_point.sh"
source "${dir}/lib/get_mount_unit.sh"
source "${dir}/lib/get_watch_path.sh"

# COMMAND -------------------------------------------------------------------------------------------

commands=('set' 'unset' 'print' 'uninstall' 'quit')

if [ -z "$cli_cmd" ] || [[ ! " ${commands[@]} " =~ " ${cli_cmd} " ]]; then

   echo 'Select command: '
   echo '1. set job'
   echo '2. unset job'
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

if [ "$cli_cmd" == 'quit' ]; then
   printf '%s' "$cli_cmd"
   exit
fi

if [ "$cli_cmd" == 'uninstall' ]; then

   systemctl stop "$name.service"
   systemctl disable "$name.service"
   systemctl daemon-reload
   rm -f "$service_file"
   exit
fi

if [ "$cli_cmd" == 'print' ]; then

   print_jobs
   exit
fi

if [ "$cli_cmd" == 'set' ]; then

   read_jobs

   source "${dir}/lib/set_job.sh"

   set_job

   exit
fi

if [ "$cli_cmd" == 'unset' ]; then

   source "${dir}/lib/unset_job.sh"
   exit
fi