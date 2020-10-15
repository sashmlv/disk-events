#!/usr/bin/env bash

function get_watch_path {

   declare mount_point="${1:-}"
   declare path="${2:-}"
   declare watch_path=

   if [[ -z "${mount_point}" ]]; then

      log "get_watch_path: Can't get watch path, provide mount point\n" >&2
      echo false
      return
   elif [[ -z "${path}" ]]; then

      log "get_watch_path: Can't get watch path, provide watching path\n" >&2
      echo false
      return
   else

      path=$(echo "${path}" | sed 's/^\(\.\/\|\/\)//')
      watch_path="${mount_point}/${path}"

      echo "${watch_path}"
      return
   fi
}
