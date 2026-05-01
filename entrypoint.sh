#!/bin/sh
# entrypoint.sh - Sleep-based daily scheduler. Runs backup.sh once per day at
# BACKUP_HOUR (container time), with optional immediate run at startup.
#
# We deliberately do not use a cron daemon: dcron's crond is not executable
# by non-root users, and crond is not built into Alpine's base BusyBox. A
# tiny shell loop is reliable, runs as any user, and tini handles signals.
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

USER_NAME=$(id -un)
echo "Scheduled daily backup at ${HOUR}:00 (container time, user=$USER_NAME)."

if [ "${RUN_AT_STARTUP:-0}" = "1" ]; then
    echo "RUN_AT_STARTUP=1 - running an immediate backup."
    /usr/local/bin/backup.sh || echo "Initial backup completed with errors." >&2
fi

HOUR_SECS=$((HOUR * 3600))
while true; do
    now=$(date +%s)
    sec_today=$((now % 86400))
    if [ "$sec_today" -lt "$HOUR_SECS" ]; then
        sleep_for=$((HOUR_SECS - sec_today))
    else
        sleep_for=$((86400 - sec_today + HOUR_SECS))
    fi
    echo "Next backup in ${sleep_for}s (now: $(date '+%Y-%m-%d %H:%M:%S %Z'))."
    sleep "$sleep_for"
    /usr/local/bin/backup.sh || echo "Backup completed with errors." >&2
done
