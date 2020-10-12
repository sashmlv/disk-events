#!/usr/bin/env bash

# start service if no exists process found

function service_start {

   previous_pid=$(cat 2>/dev/null "$pid_file")

   if ! kill -0 -"$previous_pid" 2>/dev/null; then
      systemctl enable "$name.service"
      systemctl start "$name.service"
      systemctl daemon-reload
   fi

   exit
}
