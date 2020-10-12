#!/usr/bin/env bash

readonly name='disk-events'
readonly jobs_file="${dir}/tmp/$name.jobs"
readonly tmp_file="${dir}/tmp/$name.tmp"
readonly pid_file="${dir}/tmp/$name.pid"
readonly log_file="${dir}/tmp/$name.log"
readonly process_file="${dir}/lib/job/process.sh"
readonly service_file="/etc/systemd/system/$name.service"
log=true

source "${dir}/lib/functions/log.sh"

if [[ ! -x "$(command -v fswatch)" ]]; then

   log '"fswatch" not found, please install "fswatch"\n'
   exit
fi

source "${dir}/lib/functions/read_jobs.sh"

read_jobs

source "${dir}/lib/cli_arguments.sh"
source "${dir}/lib/functions/validate.sh"
source "${dir}/lib/commands/print_jobs.sh"
source "${dir}/lib/commands/print_service.sh"
source "${dir}/lib/commands/service_start.sh"
source "${dir}/lib/commands/service_stop.sh"
source "${dir}/lib/commands/service_status.sh"
source "${dir}/lib/functions/get_mount_point.sh"
source "${dir}/lib/functions/get_mount_unit.sh"
source "${dir}/lib/functions/get_watch_path.sh"
source "${dir}/lib/functions/set_job.sh"
source "${dir}/lib/functions/unset_job.sh"
source "${dir}/lib/functions/install.sh"

# COMMAND -------------------------------------------------------------------------------------------

commands=('set' 'unset' 'print' 'print-service' 'start' 'stop' 'status' 'uninstall' 'quit')

if [ -z "$cli_cmd" ] || [[ ! " ${commands[@]} " =~ " ${cli_cmd} " ]]; then

   echo 'Select command: '
   echo '1. set job'
   echo '2. unset job'
   echo '3. print jobs'
   echo '4. print service file'
   echo '5. service start'
   echo '6. service stop'
   echo '7. service status'
   echo '8. uninstall'
   echo '9. quit'
   read cli_cmd
   case "$cli_cmd" in
      1) cli_cmd='set';;
      2) cli_cmd='unset';;
      3) cli_cmd='print';;
      4) cli_cmd='print-service';;
      5) cli_cmd='start';;
      6) cli_cmd='stop';;
      7) cli_cmd='status';;
      8) cli_cmd='uninstall';;
      9) cli_cmd='quit';;
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
   previous_pid=$(cat 2>/dev/null "$pid_file")
   kill -- -"$previous_pid" 2>/dev/null
   exit
fi

if [ "$cli_cmd" == 'print' ]; then

   print_jobs
   exit
fi

if [ "$cli_cmd" == 'print-service' ]; then

   print_service
   exit
fi

if [ "$cli_cmd" == 'start' ]; then

   install
   service_start
   exit
fi

if [ "$cli_cmd" == 'stop' ]; then

   service_stop
   exit
fi

if [ "$cli_cmd" == 'status' ]; then

   service_status
   exit
fi

if [ "$cli_cmd" == 'set' ]; then

   install
   set_job
   exit
fi

if [ "$cli_cmd" == 'unset' ]; then

   install
   unset_job
   exit
fi