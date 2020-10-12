#!/usr/bin/env bash

function service_start {

   systemctl enable "$name.service"
   systemctl start "$name.service"
   systemctl daemon-reload
   exit
}
