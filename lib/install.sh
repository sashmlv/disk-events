#!/usr/bin/env bash

# add log file
if [[ ! -f "$log_file" ]]; then

   touch "$log_file"
   printf "Log file created: %s\n" "$log_file"
fi

# add jobs file
if [[ ! -f "$jobs_file" ]]; then

   touch "$jobs_file"
   log "File for jobs created: %s\n" "$jobs_file"
fi

# fix process file
if [[ -f "$process_file" ]] && [[ ! -x "$process_file" ]] ; then

   chmod +x "$process_file"
   log "Added execute permissions for process file: %s\n" "$process_file"
fi

# add service for disk mount/unmount monitoring
if [[ ! -f "$service_file" ]]; then

   touch "$service_file" 2> /dev/null || {
      log "Can't write service file, permission denied: %s\n" "$service_file"
      exit
   }

   cat > "$service_file" <<EOF
[Unit]

[Service]
KillMode=process
ExecStart=$process_file --log=true

[Install]
EOF

   log "Service file added: %s\n" "$service_file"
fi
