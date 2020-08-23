#!/usr/bin/env bash

declare -A devs
declare -A watch_paths
watch_opts=()
mount_point=
path=

readonly SED_CUT_DEV='s/^PKNAME="\|"\sLABEL.\+//g' # cut dev
readonly SED_CUT_MOUNT='s/.\+MOUNTPOINT="\|\"$//g' # cut mount

while read line; do

   for id in "${ids[@]}"; do

      if [[ "$line" =~ "${labels[$id]}" ]]; then

         devs["$id"]=$(echo "$line" | sed "$SED_CUT_DEV")
         mount_point=$(echo "$line" | sed "$SED_CUT_MOUNT")
         path=$(echo "${paths[$id]}" | sed 's/^\(\.\/\|\/\)//')


         if [ ! -z "$path" ]; then

            watch_path="$mount_point/$path"
         else

            watch_path="$mount_point"
         fi

         if [[ ! -z "$watch_path" && ( -d "$watch_path" || -f "$watch_path" ) ]]; then

            watch_paths["$id"]="$watch_path"
            watch_opts+=("${fswatch_opts[$id]}")
         fi
      fi
   done
done < <(lsblk -Ppo pkname,label,mountpoint)

if [[ "${#watch_paths[@]}" -eq 0 ]]; then

   log '%s: No path found for watching\n' "$NAME"
   exit
fi
