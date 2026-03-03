#!/usr/bin/env bash
set -e

source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="mobile"
REPO_DIR="$HOME/obsidian"
SHARED_DIR="$HOME/storage/shared/obsidian"
FORCE_LOCAL=false

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
    git commit -m "Sync ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"
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

rsync -avu --delete "$REPO_DIR/" "$SHARED_DIR/"
