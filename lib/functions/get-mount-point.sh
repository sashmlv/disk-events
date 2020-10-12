#!/usr/bin/env bash

function get_mount_point {

   declare label="${1:-}"
   declare no_log="${2:-}"
   declare mount_point=
   readonly sed_cut_mount='s/.\+MOUNTPOINT="\|\"$//g' # cut mount

   if [[ -z "${label}" ]]; then

      log "mount_point: Can't get mount point, provide disk label\n" >&2
      echo false
      return
   fi

   # find mount point
   while read line; do

      if [[ "${line}" =~ "${label}" ]]; then

         mount_point=$(echo "${line}" | sed "${sed_cut_mount}")
      fi
   done < <(lsblk -Ppo pkname,label,mountpoint)

   if [[ -z "${mount_point}" ]]; then

      if [[ ! "${no_log}" == "no-log" ]]; then

         log "mount_point: Can't get mount point, try mount disk before: %s\n" "${label}" >&2
      fi
      echo false
      return
   else

      echo "${mount_point}"
      return
   fi
}
