# GitHub Backup Docker Container

[![Build and push Docker image](https://github.com/djlactose/github_backup/actions/workflows/docker-build.yml/badge.svg)](https://github.com/djlactose/github_backup/actions/workflows/docker-build.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/djlactose/github_backup.svg)](https://hub.docker.com/r/djlactose/github_backup)

This project provides a Docker container that performs daily mirror-clone backups of your GitHub repositories. A small shell scheduler (running under [tini](https://github.com/krallin/tini)) wakes once per day at the configured hour and runs the backup script. Optionally, set `RUN_AT_STARTUP=1` to also run an immediate backup when the container starts.

The published image is available on Docker Hub at [`djlactose/github_backup`](https://hub.docker.com/r/djlactose/github_backup):

- `djlactose/github_backup:latest` — built from the `main` branch
- `djlactose/github_backup:beta` — built from the `develop` branch
- `djlactose/github_backup:<short-sha>` — every push gets an immutable tag

> **Note:**  
> For private repositories, organization repos, or higher API rate limits, supply a GitHub token via the `GITHUB_TOKEN` environment variable. For public repos only, you can use just `GITHUB_USER`.

## Features

- **Automated Daily Backups:** The entrypoint runs a tiny sleep-based scheduler that fires `backup.sh` once per day at `BACKUP_HOUR` (container time). No cron daemon is involved, so the container runs cleanly as a non-root user. Output goes straight to the container's stdout, so `docker logs` shows backup output without an unbounded log file.
- **Mirror Cloning:** Uses `git clone --mirror` to preserve all refs (branches, tags, notes).
- **Pagination & Filters:** Iterates the GitHub API across all pages and supports `SKIP_FORKS` / `SKIP_ARCHIVED` filters.
- **User and Org Targets:** Backs up the authenticated user's repos and/or any number of orgs listed in `GITHUB_ORGS`.
- **Token Hygiene:** The token is passed to `git` per-invocation via `http.extraHeader` and is **never written to the on-disk git config** of the mirrors.
- **Non-root Runtime:** The container runs as user `backup` (UID/GID 1000). See the [Volume Permissions](#volume-permissions) note below if you are upgrading.
- **Healthcheck:** Container is unhealthy if the entrypoint scheduler exits.
- **Multi-arch:** CI publishes `linux/amd64` and `linux/arm64` images.

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `GITHUB_USER` | _(unset)_ | GitHub username for public-repo backup. Required only when `GITHUB_TOKEN` and `GITHUB_ORGS` are both unset. Ignored when `GITHUB_TOKEN` is set. |
| `GITHUB_TOKEN` | _(unset)_ | GitHub token. When set, the container fetches `/user/repos` (the token owner's repos, including private) and uses the token for all org/user requests. |
| `GITHUB_ORGS` | _(unset)_ | Comma-separated list of organizations to back up in addition to the user's repos. Example: `acme,foo-bar`. |
| `BACKUP_HOUR` | `2` | Hour (0–23) when the backup runs each day, interpreted in the container's local time (UTC unless you set `TZ`; see [Timezone](#timezone)). |
| `RUN_AT_STARTUP` | `0` | Set to `1` to run a backup immediately on container start, in addition to the scheduled daily run. |
| `SKIP_FORKS` | `0` | Set to `1` to skip forked repositories. |
| `SKIP_ARCHIVED` | `0` | Set to `1` to skip archived repositories. |

## Volumes

- **`/backup`** — Where mirror clones are written, organized as `/backup/<owner>/<repo>.git`. Mount a host directory or named volume here.

### Volume Permissions

The container runs as UID 1000 (`backup` user). On bind-mounted host directories you must ensure that UID can write to them:

```bash
sudo chown -R 1000:1000 /path/on/host
```

If you are **upgrading from an older version** that ran as root, the existing `/backup` contents are owned by `root` (UID 0) and the new container will fail to write. Run the `chown` above once before starting the new container.

## Timezone

`BACKUP_HOUR` is interpreted in the container's local time. The container defaults to UTC. To run the backup at a specific local hour, pass a `TZ` env var with an IANA name:

```bash
-e TZ=America/Los_Angeles
```

The image includes `tzdata`, so any IANA zone (e.g. `Europe/Berlin`, `Asia/Tokyo`) works directly. DST transitions are handled by the underlying `date` calls each iteration, so the backup keeps firing at the same wall-clock hour across the changeover.

## Run

```bash
docker run -d \
  --name github-backup \
  -e GITHUB_TOKEN=ghp_your_token_here \
  -e GITHUB_ORGS=acme,foo \
  -e BACKUP_HOUR=2 \
  -e RUN_AT_STARTUP=1 \
  -e SKIP_FORKS=1 \
  -v /path/on/host:/backup \
  --restart unless-stopped \
  djlactose/github_backup:latest
```

`docker logs -f github-backup` streams the backup output.

## Build Locally

```bash
git clone https://github.com/djlactose/github_backup.git
cd github_backup
docker build -t github-backup .
```

A PowerShell helper, [`docker_build.ps1`](docker_build.ps1), tags with `:latest` plus the current git short SHA and pushes both. CI is the source of truth for published images; the script is for ad-hoc dev pushes.

## Continuous Integration

[`.github/workflows/docker-build.yml`](.github/workflows/docker-build.yml) builds and pushes on every push to `main` (tag `latest`) or `develop` (tag `beta`), plus a `<short-sha>` tag on every build. To enable, set the following secrets in your GitHub repo:

- `DOCKERHUB_USERNAME` — Docker Hub username
- `DOCKERHUB_TOKEN` — Docker Hub access token (Account Settings → Security → New Access Token)

The workflow can also be triggered manually via the **Run workflow** button (`workflow_dispatch`).

## Project Structure

- **`Dockerfile`** — Alpine 3.21 base, installs `git curl jq tini tzdata`, creates the non-root `backup` user, sets the `HEALTHCHECK`, and runs `tini -- /entrypoint.sh`.
- **`entrypoint.sh`** — Validates `BACKUP_HOUR`, optionally fires an immediate backup when `RUN_AT_STARTUP=1`, then enters a sleep loop that wakes once per day at the configured hour and invokes `backup.sh`.
- **`backup.sh`** — Iterates the user's repos and (optionally) each org's repos, applies `SKIP_*` filters, and mirror-clones or updates each into `/backup/<owner>/<repo>.git`.
- **`.github/workflows/docker-build.yml`** — CI build & push.
- **`docker_build.ps1`** — Local Windows helper for ad-hoc dev pushes.
