#!/usr/bin/env bash
set -e

source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="mobile"
REPO_DIR="$HOME/obsidian"
SHARED_DIR="$HOME/storage/shared/obsidian"
FORCE_LOCAL=false

COMMIT_MESSAGE="Sync ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"

for arg in "$@"; do
    if [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
        FORCE_LOCAL=true
    fi
done

rsync -av --update "$SHARED_DIR/" "$REPO_DIR/"

cd "$REPO_DIR"

git config core.fileMode false

git add -A
if ! git diff --cached --quiet; then
    git commit -m "$COMMIT_MESSAGE"
fi

if [ "$FORCE_LOCAL" = true ]; then
    git fetch origin
    git push origin main --force
else
    if ! git pull --rebase --autostash origin main; then
        git rebase --abort
        termux-toast "Conflicto en Git. Resuelve en el PC o revisa los archivos."
        exit 1
    fi
    git push origin main
fi

python3 "$HOME/scripts/update-todos.py" "$REPO_DIR"
rsync -avu --delete "$REPO_DIR/" "$SHARED_DIR/"
