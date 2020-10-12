#!/usr/bin/env bash

function service_stop {

   systemctl stop "$name.service"
   systemctl daemon-reload
   exit
}
