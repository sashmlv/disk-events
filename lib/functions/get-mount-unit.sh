#!/usr/bin/env bash

function get_mount_unit {

   declare label="${1:-}"
   declare no_log="${2:-}"
   declare mount_unit=
   if [[ -z "${label}" ]]; then

      log "Can't get mount unit, provide disk label\n"
      echo false
      return
   fi

   mount_unit=$(systemctl list-units -t mount | awk 'match($0, /\ *(.+\.mount)\ */) { str=substr($0, RSTART, RLENGTH); print str }' | xargs -r -0 systemd-escape -u | grep "${label}" | awk '{$1=$1};1' | xargs -r -d '\n' systemd-escape | sed 's/\x/\\x/g')

   if [[ -z "$mount_unit" ]]; then

      if [[ ! "${no_log}" == "no-log" ]]; then

         log "Can't get mount unit, for: %s\n" "$label"
      fi
      echo false
      return
   else

      echo "${mount_unit}"
      return
   fi
}
