#!/usr/bin/env bash

# add jobs file
if [ ! -f "$JOBS_FILE" ]; then

   touch "$JOBS_FILE"
fi

# fix process file
if [[ -f "$PROCESS_FILE" ]] && [[ -x "$PROCESS_FILE" ]] ; then

   chmod +x "$PROCESS_FILE"
fi

# add service for disk mount/unmount monitoring
if [ ! -f "$SERVICE_FILE" ]; then

   touch "$SERVICE_FILE" 2> /dev/null || {
      printf "Can't write service file, permission denied: %s\n" "$SERVICE_FILE"
      exit
   }

   cat > "$SERVICE_FILE" <<EOF
[Unit]

[Service]
KillMode=process
ExecStart=$PROCESS_FILE --log=true

[Install]
EOF
fi
