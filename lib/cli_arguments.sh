#!/usr/bin/env bash

declare cli_cmd="${1:-}"
declare cli_id=
declare cli_label=
declare cli_path=
declare cli_timeout=
declare cli_job_cmd=
declare cli_fswatch_opt=

if [[ ! -z "$cli_cmd" ]]; then shift; fi

if [[ ! -z "$*" ]]; then

   var_name=

   # parse cli arguments into cli variables
   while [ ! -z "$*" ]; do
      case $1 in
         --label|--label=) var_name='cli_label';shift;;
         --path|--path=) var_name='cli_path';shift;;
         --timeout|--timeout=) var_name='cli_timeout';shift;;
         --command|--command=) var_name='cli_job_cmd';shift;;
         --fswatch|--fswatch=) var_name='cli_fswatch_opt';shift;;
         *) declare "$var_name"+="$1 ";shift;;
      esac
   done

   # remove last space added abowe
   if [[ ! -z "$cli_label" ]]; then cli_label=$(echo "$cli_label" | sed 's/\s$//'); fi
   if [[ ! -z "$cli_path" ]]; then cli_path=$(echo "$cli_path" | sed 's/\s$//'); fi
   if [[ ! -z "$cli_timeout" ]]; then cli_timeout=$(echo "$cli_timeout" | sed 's/\s$//'); fi
   if [[ ! -z "$cli_job_cmd" ]]; then cli_job_cmd=$(echo "$cli_job_cmd" | sed 's/\s$//'); fi
   if [[ ! -z "$cli_fswatch_opt" ]]; then cli_fswatch_opt=$(echo "$cli_fswatch_opt" | sed 's/\s$//'); fi
fi
