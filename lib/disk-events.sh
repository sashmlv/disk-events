#!/usr/bin/env bash

readonly name='disk-events'
readonly jobs_file="${dir}/tmp/$name.jobs"
readonly tmp_file="${dir}/tmp/$name.tmp"
readonly pid_file="${dir}/tmp/$name.pid"
readonly log_file="${dir}/tmp/$name.log"
readonly process_file="${dir}/lib/job/process.sh"
readonly service_file="/etc/systemd/system/$name.service"

ids=()
declare -A labels=()
declare -A paths=()
declare -A timeouts=()
declare -A job_cmds=()
declare -A fswatch_opts=()

logger=true

source "${dir}/lib/functions/log.sh"

if [[ ! -x "$(command -v fswatch)" ]]; then

   log 'disk-events: "fswatch" not found, please install "fswatch"\n'
   exit
fi

source "${dir}/lib/functions/read-jobs.sh"

read_jobs

source "${dir}/lib/cli-arguments.sh"
source "${dir}/lib/functions/validate.sh"
source "${dir}/lib/commands/print-jobs.sh"
source "${dir}/lib/commands/print-service.sh"
source "${dir}/lib/commands/service-start.sh"
source "${dir}/lib/commands/service-stop.sh"
source "${dir}/lib/commands/service-status.sh"
source "${dir}/lib/functions/get-mount-point.sh"
source "${dir}/lib/functions/get-mount-unit.sh"
source "${dir}/lib/functions/get-watch-path.sh"
source "${dir}/lib/functions/set-job.sh"
source "${dir}/lib/functions/unset-job.sh"
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
   log 'disk-events: Disabled service: "%s"\n' "$name.service"
   rm -f "$service_file"
   log 'disk-events: Removed service file: "%s"\n' "$service_file"
   previous_pid=$(cat 2>/dev/null "$pid_file")
   kill -- -"$previous_pid" 2>/dev/null
   log 'disk-events: Process killed: "%s"\n' "$previous_pid"
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
   log 'disk-events: Service starded\n'
   exit
fi

if [ "$cli_cmd" == 'stop' ]; then

   service_stop
   log 'disk-events: Service stopped\n'
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