#!/bin/sh
# backup.sh - backup all GitHub repositories for the given user with pagination

# Check that GITHUB_USER is provided
if [ -z "$GITHUB_USER" ]; then
    echo "Error: GITHUB_USER environment variable is not set."
    exit 1
fi

# Set the API endpoint and headers
if [ -n "$GITHUB_TOKEN" ]; then
    API_URL="https://api.github.com/user/repos?per_page=100"
    AUTH_HEADER="Authorization: token $GITHUB_TOKEN"
else
    API_URL="https://api.github.com/users/$GITHUB_USER/repos?per_page=100"
    AUTH_HEADER=""
fi

page=1
while true; do
    echo "Fetching repositories (page $page)..."
    # Fetch the current page of repositories
    if [ -n "$AUTH_HEADER" ]; then
        REPOS_JSON=$(curl -s -H "$AUTH_HEADER" "${API_URL}&page=${page}")
    else
        REPOS_JSON=$(curl -s "${API_URL}&page=${page}")
    fi

    # If the response is completely empty, exit the loop
    if [ -z "$REPOS_JSON" ]; then
        echo "Empty response on page $page. Exiting loop."
        break
    fi

    # Use jq to determine the number of repositories in the response
    repo_count=$(echo "$REPOS_JSON" | jq 'length')
    if [ "$repo_count" -eq 0 ]; then
        echo "No repositories found on page $page. Exiting loop."
        break
    fi

    # Process each repository returned on this page
    echo "$REPOS_JSON" | jq -r '.[] | "\(.full_name) \(.clone_url)"' | while read full_name clone_url; do
        # Extract owner and repo name from full_name
        owner=$(echo "$full_name" | cut -d'/' -f1)
        repo=$(echo "$full_name" | cut -d'/' -f2)

        # Define the local backup directory (using mirror clone for a full backup)
        backup_dir="/backup/$owner/$repo.git"

        # If using a token, insert it into the clone URL (be cautious with token exposure)
        if [ -n "$GITHUB_TOKEN" ]; then
            clone_url=$(echo "$clone_url" | sed "s#https://#https://${GITHUB_TOKEN}@#")
        fi

        echo "Processing $full_name ..."
        # Ensure the owner directory exists
        mkdir -p "/backup/$owner"

        # If the repository hasn't been cloned before, perform a mirror clone.
        if [ ! -d "$backup_dir" ]; then
            echo "Cloning $full_name into $backup_dir..."
            git clone --mirror "$clone_url" "$backup_dir"
        else
            echo "Updating existing backup for $full_name in $backup_dir..."
            cd "$backup_dir" || continue
            git remote update
        fi
    done

    # Increment page number for the next iteration
    page=$((page + 1))
done

echo "Backup complete."
