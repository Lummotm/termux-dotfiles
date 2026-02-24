#!/usr/bin/env bash
set -e

source ~/.termux_device_info 2>/dev/null || TERMUX_DEVICE_NAME="mobile"
repo="$HOME/obsidian"
shared="$HOME/storage/shared/obsidian"
FORCE_LOCAL=false

for arg in "$@"; do
    if [ "$arg" == "-f" ] || [ "$arg" == "--force" ]; then
        FORCE_LOCAL=true
    fi
done

cd "$repo"

# 1. Import from shared to repo (mirror exact state)
rsync -av --delete "$shared/" "$repo/"

# 2. Commit changes
git add -A
if ! git diff --cached --quiet; then
    git commit -m "Sync ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"
fi

# 3. Sync with remote
if [ "$FORCE_LOCAL" = true ]; then
    git fetch origin
    git push origin main --force
else
    # Rebase strategy: local changes win conflicts (-X theirs)
    git pull --rebase --autostash -X theirs origin main || {
        git rebase --abort
        exit 1
    }
    git push origin main
fi

# 4. Export to shared (update only, do not delete new files)
rsync -avu "$repo/" "$shared/"
