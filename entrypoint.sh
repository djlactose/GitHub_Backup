#!/bin/sh
# entrypoint.sh - generate the crontab from BACKUP_HOUR, optionally run an
# immediate backup, then hand off to crond. Cron job stdout/stderr is wired
# straight to PID 1's fds so `docker logs` shows backup output without a
# log file that would grow without bound.
set -eu

HOUR=${BACKUP_HOUR:-2}
case "$HOUR" in
    ''|*[!0-9]*)
        echo "BACKUP_HOUR must be an integer 0-23 (got: '$HOUR')" >&2
        exit 1
        ;;
esac
HOUR=$((10#$HOUR))
if [ "$HOUR" -lt 0 ] || [ "$HOUR" -gt 23 ]; then
    echo "BACKUP_HOUR must be in the range 0-23 (got: $HOUR)" >&2
    exit 1
fi

# crond (dcron) reads /etc/crontabs/<running-user> for non-root invocations.
USER_NAME=$(id -un)
mkdir -p /etc/crontabs
echo "0 $HOUR * * * /usr/local/bin/backup.sh > /proc/1/fd/1 2>/proc/1/fd/2" > "/etc/crontabs/$USER_NAME"
echo "Scheduled daily backup at ${HOUR}:00 (container time, user=$USER_NAME)."

if [ "${RUN_AT_STARTUP:-0}" = "1" ]; then
    echo "RUN_AT_STARTUP=1 - running an immediate backup in the background."
    /usr/local/bin/backup.sh &
fi

exec crond -f -l 8
