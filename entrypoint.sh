#!/bin/sh
# Start the cron daemon in the background
crond

# (Optional) Touch the log file in case it doesn't exist
touch /var/log/backup.log

# Tail the backup log so that Docker shows the output
tail -f /var/log/backup.log
