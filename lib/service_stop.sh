#!/usr/bin/env bash

function service_stop {

   systemctl stop "$name.service"
   exit
}
