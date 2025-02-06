# GitHub Backup Docker Container

This project provides a Docker container that performs daily backups of your GitHub repositories locally. Instead of using cron, the container runs an infinite loop that checks the current time every hour. When the current hour matches the scheduled backup time (configurable via an environment variable), the backup script is executed once per day.

> **Note:**  
> For private repositories or higher API rate limits, supply a GitHub token via the `GITHUB_TOKEN` environment variable. If you only need to backup public repositories, this variable can be omitted.

## Features

- **Automated Daily Backups:**  
  The container’s entrypoint script runs an infinite loop that checks every hour. When the current hour matches the configured backup hour, it runs the backup script (only once per day).

- **Mirror Cloning:**  
  Uses `git clone --mirror` to perform complete backups of your repositories, preserving all refs (branches, tags, etc.).

- **GitHub API Integration with Pagination:**  
  The backup script fetches all repositories using the GitHub API (handling pagination if you have more than 100 repositories).

- **Volume Persistence:**  
  Backups are stored on a host-mounted volume so that they persist even if the container restarts.

- **Configurable Backup Time:**  
  Specify the desired backup hour (in 24-hour format) using the `BACKUP_HOUR` environment variable (default is `2` for 2 AM).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed on your system.
- A GitHub username.
- Optionally, a GitHub token with the appropriate permissions if you need to backup private repositories or require higher API rate limits.

## Project Structure

- **Dockerfile:**  
  Builds the image using Alpine Linux, installs required packages (`git`, `curl`, `jq`), and copies the backup and entrypoint scripts.

- **backup.sh:**  
  The script that fetches all GitHub repositories (with pagination) and either mirror-clones or updates the backup for each repository.

- **entrypoint.sh:**  
  The script that runs in an infinite loop, checking the current hour every 3600 seconds. If the current hour matches the configured backup hour (and the backup hasn’t already been run that day), it triggers `backup.sh`.

## Environment Variables

The container supports the following environment variables:

- **GITHUB_USER** (required):  
  Your GitHub username. This is used to fetch your public repositories (or private ones if a token is provided).

- **GITHUB_TOKEN** (optional):  
  A GitHub token with the necessary permissions. If provided, this allows the container to access private repositories and increases the API rate limit.

- **BACKUP_HOUR** (optional):  
  The hour (in 24-hour format) when the backup should run each day. If not provided, the default value is `2` (i.e., 2 AM).

## Volumes

- **/backup**:  
  The directory inside the container where backups are stored. It is recommended to mount a host directory to this path to persist backup data between container restarts.

## Docker Build & Run Instructions

### 1. Clone This Repository

Clone the project repository to your local machine:

```bash
git clone https://github.com/yourusername/github-backup.git
cd github-backup
