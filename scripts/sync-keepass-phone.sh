#!/usr/bin/env bash
set -e

source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="móvil"
REPO_DIR="$HOME/keepass"
SHARED_DIR="$HOME/storage/shared/keepass"

rsync -a --delete "$SHARED_DIR/" "$REPO_DIR/"

cd "$REPO_DIR"

git rebase --abort >/dev/null 2>&1 || true

git add -A
if ! git diff --cached --quiet; then
    git commit -m "Sync KeePass ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"
fi

# Gana el pc en pull
if ! git pull --rebase -Xtheirs origin main; then
    echo "Conflicto binario detectado, forzando versión del servidor..."
    git rebase --abort
    git fetch origin main
    git reset --hard origin/main
fi

git push origin main

rsync -a --delete "$REPO_DIR/" "$SHARED_DIR/"
