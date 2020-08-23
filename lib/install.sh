#!/usr/bin/env bash

# add jobs file
if [ ! -f "$JOBS_FILE" ]; then

   touch "$JOBS_FILE"
fi

# fix jobs file
if [ ! -f "JOB_FILE" ]; then

   chmod +x "$JOB_FILE"
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
ExecStart=$JOB_FILE --log=true

[Install]
EOF
fi
