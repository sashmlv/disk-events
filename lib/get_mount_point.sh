#!/usr/bin/env bash

function get_mount_point {

   local label="${1:-}"
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

      log "mount_point: Can't get mount point, try mount disk before: %s\n" "${label}" >&2
      echo false
      return
   else

      echo "${mount_point}"
      return
   fi
}
