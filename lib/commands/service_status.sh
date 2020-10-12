#!/usr/bin/env bash

function service_status {

   systemctl status "$name.service"
   exit
}
