#!/bin/sh
# backup.sh - mirror-clone (or update) every repository visible to the
# configured GitHub user/token (and any orgs in GITHUB_ORGS), with pagination.
#
# Per-repo failures are tolerated so a single broken clone does not abort
# the whole backup; API-level errors (rate limit, auth) are fatal.
set -u

# GITHUB_USER is only required when no token is supplied; with a token we
# fetch /user/repos which already targets the token's owner.
if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${GITHUB_USER:-}" ] && [ -z "${GITHUB_ORGS:-}" ]; then
    echo "Error: set GITHUB_TOKEN, GITHUB_USER, or GITHUB_ORGS." >&2
    exit 1
fi

PER_PAGE=100
SKIP_FORKS=${SKIP_FORKS:-0}
SKIP_ARCHIVED=${SKIP_ARCHIVED:-0}

# Wrapper so the token is passed in-process to git without ever being written
# into the on-disk remote config of the mirror.
git_auth() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        git -c "http.extraHeader=Authorization: token $GITHUB_TOKEN" "$@"
    else
        git "$@"
    fi
}

curl_api() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -sS -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$1"
    else
        curl -sS -H "Accept: application/vnd.github+json" "$1"
    fi
}

# fetch_and_mirror <api-url-base> <label>
# Iterates pages from <api-url-base>?per_page=100&page=N, applying SKIP_*
# filters, then mirror-clones or updates each repo into /backup/<owner>/<repo>.git.
fetch_and_mirror() {
    base_url=$1
    label=$2
    page=1

    while true; do
        echo "[$label] Fetching repositories (page $page)..."
        response=$(curl_api "${base_url}?per_page=${PER_PAGE}&page=${page}")

        if [ -z "$response" ]; then
            echo "[$label] Empty response on page $page. Stopping."
            return 0
        fi

        if ! echo "$response" | jq -e 'type == "array"' >/dev/null 2>&1; then
            msg=$(echo "$response" | jq -r '.message // "unexpected response shape"')
            echo "[$label] GitHub API error on page $page: $msg" >&2
            return 1
        fi

        repo_count=$(echo "$response" | jq 'length')
        if [ "$repo_count" -eq 0 ]; then
            echo "[$label] No repositories on page $page. Done."
            return 0
        fi

        echo "$response" | jq -r --arg skip_forks "$SKIP_FORKS" --arg skip_archived "$SKIP_ARCHIVED" '
            .[]
            | select(($skip_forks    != "1") or (.fork     == false))
            | select(($skip_archived != "1") or (.archived == false))
            | "\(.full_name) \(.clone_url)"
        ' | while read -r full_name clone_url; do
            [ -n "$full_name" ] || continue
            owner=${full_name%%/*}
            repo=${full_name#*/}
            backup_dir="/backup/$owner/$repo.git"

            echo "Processing $full_name ..."
            mkdir -p "/backup/$owner"

            if [ ! -d "$backup_dir" ]; then
                if ! git_auth clone --mirror "$clone_url" "$backup_dir"; then
                    echo "  ! Failed to clone $full_name; continuing." >&2
                fi
            else
                if ! git_auth -C "$backup_dir" remote update --prune; then
                    echo "  ! Failed to update $full_name; continuing." >&2
                fi
            fi
        done

        if [ "$repo_count" -lt "$PER_PAGE" ]; then
            return 0
        fi
        page=$((page + 1))
    done
}

exit_status=0

if [ -n "${GITHUB_TOKEN:-}" ]; then
    fetch_and_mirror "https://api.github.com/user/repos" "user (token)" || exit_status=1
elif [ -n "${GITHUB_USER:-}" ]; then
    fetch_and_mirror "https://api.github.com/users/${GITHUB_USER}/repos" "user ${GITHUB_USER}" || exit_status=1
fi

if [ -n "${GITHUB_ORGS:-}" ]; then
    # Comma-separated list of orgs; trim whitespace per entry.
    OLD_IFS=$IFS
    IFS=','
    for org in $GITHUB_ORGS; do
        org=$(echo "$org" | tr -d '[:space:]')
        [ -n "$org" ] || continue
        fetch_and_mirror "https://api.github.com/orgs/${org}/repos" "org ${org}" || exit_status=1
    done
    IFS=$OLD_IFS
fi

if [ "$exit_status" -eq 0 ]; then
    echo "Backup complete."
else
    echo "Backup completed with errors." >&2
fi
exit "$exit_status"
