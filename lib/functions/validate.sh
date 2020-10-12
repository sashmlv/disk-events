#!/usr/bin/env bash

function validate {

   declare -r key="${1:-}"
   declare -r val="${2:-}"
   declare -r log="${3:-log}"

   readonly unsafe_rgx="[\0\`\\\/:\;\*\"\'\<\>\|\.\,]" # UNSAFE SYMBOLS: \0 ` \ / : ; * " ' < > | . ,
   readonly num_rgx='^[0-9]+$'

   if [[ -z "${key}" ]] || [[ -z "${val}" ]]; then

      [[ "${log}" == 'log' ]] && log "validate: Can't validate parameter, empty arguments\n"
      echo false
      return

   elif [[ "${key}" == 'label' ]] && [[ "${val}" =~ $unsafe_rgx ]]; then

      [[ "${log}" == 'log' ]] && log 'validate: Disk label contains not a safe symbols\n'
      echo false
      return

   elif [[ "${key}" == 'timeout' ]] && [[ ! "${val}" =~ $num_rgx ]]; then

      [[ "${log}" == 'log' ]] && log 'validate: Job timeout not valid: %s\n' "${val}"
      echo false
      return
   fi
}
