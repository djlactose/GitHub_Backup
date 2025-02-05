#!/bin/sh
# backup.sh - backup all GitHub repositories for the given user

# Check that GITHUB_USER is provided
if [ -z "$GITHUB_USER" ]; then
    echo "Error: GITHUB_USER environment variable is not set."
    exit 1
fi

# Choose the API endpoint:
# - If a GITHUB_TOKEN is provided, we use the authenticated endpoint (this also gives access to private repos).
# - Otherwise, we use the public repos endpoint.
if [ -n "$GITHUB_TOKEN" ]; then
    API_URL="https://api.github.com/user/repos?per_page=100"
    AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
else
    API_URL="https://api.github.com/users/$GITHUB_USER/repos?per_page=100"
    AUTH_HEADER=""
fi

echo "Fetching repositories from $API_URL..."
# Fetch the list of repositories
if [ -n "$AUTH_HEADER" ]; then
    REPOS_JSON=$(curl -s -H "$AUTH_HEADER" "$API_URL")
else
    REPOS_JSON=$(curl -s "$API_URL")
fi

if [ -z "$REPOS_JSON" ]; then
    echo "Error: Failed to fetch repository data."
    exit 1
fi

# Process each repository using jq.
# We output two fields: the repository’s full_name (e.g. "username/repo") and its clone_url.
echo "$REPOS_JSON" | jq -r '.[] | "\(.full_name) \(.clone_url)"' | while read full_name clone_url; do
    # Extract owner and repo name from full_name
    owner=$(echo "$full_name" | cut -d'/' -f1)
    repo=$(echo "$full_name" | cut -d'/' -f2)

    # Define the local backup directory.
    # We use the mirror clone option so that all refs are preserved.
    backup_dir="/backup/$owner/$repo.git"

    # If using a token, modify the clone URL so that authentication is included.
    if [ -n "$GITHUB_TOKEN" ]; then
        # Note: Embedding the token in the URL can expose it in local config files.
        clone_url=$(echo "$clone_url" | sed "s#https://#https://${GITHUB_TOKEN}@#")
    fi

    echo "Processing $full_name ..."
    # Ensure the owner directory exists
    mkdir -p "/backup/$owner"

    # If the repository has not been cloned before, do a mirror clone.
    if [ ! -d "$backup_dir" ]; then
        echo "Cloning $full_name into $backup_dir..."
        git clone --mirror "$clone_url" "$backup_dir"
    else
        echo "Updating existing backup for $full_name in $backup_dir..."
        cd "$backup_dir" || continue
        git remote update
    fi
done

echo "Backup complete."
