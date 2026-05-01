FROM alpine:3.21

VOLUME ["/backup"]
ENV GITHUB_USER=
ENV GITHUB_TOKEN=
ENV BACKUP_HOUR=2
ENV RUN_AT_STARTUP=0
ENV SKIP_FORKS=0
ENV SKIP_ARCHIVED=0
ENV GITHUB_ORGS=

COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /entrypoint.sh

RUN apk add --no-cache git curl jq tini && \
    addgroup -g 1000 backup && \
    adduser -D -u 1000 -G backup -h /home/backup -s /bin/sh backup && \
    mkdir -p /backup /etc/crontabs && \
    chown -R backup:backup /backup /etc/crontabs && \
    chmod +x /usr/local/bin/backup.sh /entrypoint.sh

USER backup

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pgrep -f entrypoint.sh >/dev/null || exit 1

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
