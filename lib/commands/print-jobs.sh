#!/usr/bin/env bash

function print_jobs {

   readonly id_title='id'
   readonly label_title='label'
   readonly path_title='path'
   readonly timeout_title='timeout'
   readonly job_cmd_title='command'
   readonly fswatch_opt_title='fswatch options'

   readonly fields=('id' 'label' 'path' 'timeout' 'job_cmd' 'fswatch_opt')

   value_length=
   title_length=

   declare -A values_lengths

   for field in "${fields[@]}"; do

      eval values_lengths["$field"]="\${#${field}_title}" # get title length
   done

   # get values max length for each field
   for id in "${ids[@]}"; do

      for field in "${fields[@]}"; do

         if [ "$field" == 'id' ]; then

            eval value_length="\${#id}"
         else

            eval value_length="\${#${field}s[$id]}"
         fi

         eval title_length="\${#${field}_title}"

         if [[ "$value_length" -gt "${values_lengths[$field]}" ]]; then

            values_lengths["$field"]="$value_length"

            if [[ "${values_lengths[$field]}" -lt "$title_length" ]]; then

               values_lengths["$field"]=$(("$title_length"-2))
            fi
         fi
      done
   done

   # add two whitespaces
   for field in "${!values_lengths[@]}"; do

      values_lengths["$field"]=$(("${values_lengths[$field]}"+2))
   done

   # 1 line
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['id']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['label']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['path']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
   printf '+\n'
   # 2 line
   printf "|\033[1m $id_title\033[0m"
   printf '%'$(("${values_lengths['id']}"-1-"${#id_title}"))'s'
   printf "|\033[1m $label_title\033[0m"
   printf '%'$(("${values_lengths['label']}"-1-"${#label_title}"))'s'
   printf "|\033[1m $path_title\033[0m"
   printf '%'$(("${values_lengths['path']}"-1-"${#path_title}"))'s'
   printf "|\033[1m $timeout_title\033[0m"
   printf '%'$(("${values_lengths['timeout']}"-1-"${#timeout_title}"))'s'
   printf "|\033[1m $job_cmd_title\033[0m"
   printf '%'$(("${values_lengths['job_cmd']}"-1-"${#job_cmd_title}"))'s'
   printf "|\033[1m $fswatch_opt_title\033[0m"
   printf '%'$(("${values_lengths['fswatch_opt']}"-1-"${#fswatch_opt_title}"))'s'
   printf '|\n'
   # 3 line
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['id']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['label']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['path']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
   printf '+'
   printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
   printf '+\n'
   if [[ "${#ids[@]}" -gt 0 ]]; then

      for id in "${ids[@]}"; do
         # 4 line
         printf "| $id"
         printf '%'$(("${values_lengths['id']}"-1-"${#id}"))'s'
         printf "| ${labels[$id]}"
         printf '%'$(("${values_lengths['label']}"-1-"${#labels[$id]}"))'s'
         printf "| ${paths[$id]}"
         printf '%'$(("${values_lengths['path']}"-1-"${#paths[$id]}"))'s'
         printf "| ${timeouts[$id]}"
         printf '%'$(("${values_lengths['timeout']}"-1-"${#timeouts[$id]}"))'s'
         printf "| ${job_cmds[$id]}"
         printf '%'$(("${values_lengths['job_cmd']}"-1-"${#job_cmds[$id]}"))'s'
         printf "| ${fswatch_opts[$id]}"
         printf '%'$(("${values_lengths['fswatch_opt']}"-1-"${#fswatch_opts[$id]}"))'s'
         printf '|\n'
         # 5 line
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['id']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['label']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['path']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
         printf '+'
         printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
         printf '+\n'
      done
   else
      # 5 line
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['id']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['label']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['path']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['timeout']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['job_cmd']}")
      printf '+'
      printf '%0.s-' $(seq 1 "${values_lengths['fswatch_opt']}")
      printf '+\n'
   fi
}
