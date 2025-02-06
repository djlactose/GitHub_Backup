#!/bin/sh

# BACKUP_HOUR: the hour (in 24-hour format) when the backup should run.
# Default to 2 (2 AM) if not provided.
SCHEDULE_HOUR=${BACKUP_HOUR:-2}
# Remove any leading zeros to ensure proper numeric comparison
SCHEDULE_HOUR=$(echo "$SCHEDULE_HOUR" | sed 's/^0*//')

echo "Scheduled backup hour: $SCHEDULE_HOUR (24-hour format)"
last_backup_date=""

while true; do
    # Get the current hour (remove leading zeros) and current date.
    current_hour=$(date +%H | sed 's/^0*//')
    current_date=$(date +%Y-%m-%d)
    echo "Current time: $(date) | Hour: $current_hour | Scheduled Hour: $SCHEDULE_HOUR"

    # If the current hour matches the scheduled hour and a backup hasn't been done today:
    if [ "$current_hour" -eq "$SCHEDULE_HOUR" ] && [ "$current_date" != "$last_backup_date" ]; then
        echo "It's time to run the backup. Running backup.sh..."
        /usr/local/bin/backup.sh
        # Record the day on which the backup was performed.
        last_backup_date="$current_date"
    else
        echo "Not backup time yet or backup already performed today."
    fi

    echo "Sleeping for 1 hour..."
    sleep 3600
done
