#!/bin/bash

LAST_ACCESS=''
CURRENT_DISK=''
DISK_LABEL=''
TIMEOUT=5
BATCH_MARKER=''
MOUNT_POINTS="/media/$USER/$DISK_LABEL"
PID=''

# watch disk access events in coprocess
coproc (
   while read ACCESS_PATH;
   do

      echo "$ACCESS_PATH"

      if [[ $ACCESS_PATH =~ $DISK_LABEL ]]; then

         CURRENT_DISK=$DISK_LABEL
      fi
      if [ "$ACCESS_PATH" == "$BATCH_MARKER" ]; then

         echo "$CURRENT_DISK=$(date +"%s")"
      fi
   done < <(fswatch --batch-marker="$BATCH_MARKER" "$MOUNT_POINT")
)

function make_sleep {

   sleep $TIMEOUT
   echo "sleep $1"
}

# read and handle access events data
while read -u ${COPROC[0]};
do

   LAST_ACCESS=$REPLY
   echo $LAST_ACCESS
   kill $PID 2>/dev/null;
   make_sleep "$LAST_ACCESS" &
   PID=$!
done
