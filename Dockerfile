FROM alpine:latest

VOLUME ["/backup"]
ENV GITHUB_USER=
ENV GITHUB_TOKEN=
ENV BACKUP_HOUR=2

COPY backup.sh /usr/local/bin/backup.sh
COPY backup.cron /etc/crontabs/root
COPY entrypoint.sh /entrypoint.sh

RUN apk add --no-cache git curl jq dcron && \
mkdir -p /backup /var/log && \
chmod +x /usr/local/bin/backup.sh && \
chmod +x /entrypoint.sh

# Use the entrypoint script to start cron and keep the container running
ENTRYPOINT ["/entrypoint.sh"]
