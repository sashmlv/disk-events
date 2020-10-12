#!/usr/bin/env bash

# stop process quiet

function service_stop {

   previous_pid=$(cat 2>/dev/null "$pid_file")
   kill -- -"$previous_pid" 2>/dev/null
   systemctl stop "$name.service"
   systemctl daemon-reload
   exit
}
