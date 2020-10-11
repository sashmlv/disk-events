#!/usr/bin/env bash

function service_start {

   systemctl start "$name.service"
   exit
}
