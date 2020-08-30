#!/usr/bin/env bash

function get_mount_unit {

   local label="${1:-}"

   if [[ -z "${label}" ]]; then

      log "Can't get mount unit, provide disk label\n" >&2
      echo false
      return
   fi

   mount_unit=$(systemctl list-units -t mount | awk 'match($0, /\ *(.+\.mount)\ */) { str=substr($0, RSTART, RLENGTH); print str }' | xargs -0 systemd-escape -u | grep "${label}" | awk '{$1=$1};1' | xargs -d '\n' systemd-escape | sed 's/\x/\\x/g')

   if [[ -z "$mount_unit" ]]; then

      log "Can't get mount unit, for: %s\n" "$label" >&2
      echo false
      return
   else

      echo "${mount_unit}"
      return
   fi
}
