# GitHub Backup Docker Container

This project provides a Docker container that performs daily backups of your GitHub repositories locally. The container uses a cron job to run a backup script every day at 2 AM. It leverages the GitHub API to list repositories and uses Git’s mirror cloning to preserve all refs (branches, tags, etc.) of each repository.

> **Note:** For private repositories or higher API rate limits, you can provide a GitHub token via the `GITHUB_TOKEN` environment variable. If only public repositories are needed, this can be omitted.

## Features

- **Automated Daily Backups:** Scheduled via cron to run every day at 2 AM.
- **Mirror Cloning:** Uses `git clone --mirror` to ensure a complete backup including all refs.
- **GitHub API Integration:** Fetches repositories using either public or authenticated endpoints.
- **Volume Persistence:** Backups are stored in a host-mounted volume to ensure data persists across container restarts.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed on your system.
- A GitHub username.
- Optionally, a GitHub token with appropriate permissions if you want to backup private repositories or need higher API rate limits.

## Project Structure

- **Dockerfile**: Sets up the container, installs necessary packages (git, curl, jq, cron), and configures the environment.
- **backup.sh**: The main script that fetches the repository list from GitHub and performs cloning or updates existing backups.
- **backup.cron**: The cron configuration file that schedules `backup.sh` to run daily at 2 AM.
- **entrypoint.sh**: Starts the cron daemon and tails the log file to keep the container running.

## Setup & Usage

### 1. Clone This Repository

Clone the project repository to your local machine:

```bash
git clone https://github.com/yourusername/github-backup.git
cd github-backup
