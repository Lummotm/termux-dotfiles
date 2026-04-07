#!/usr/bin/env bash
set -e

source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="mobile"

REPO_DIR="$HOME/obsidian"
SHARED_DIR="$HOME/storage/shared/obsidian"
COMMIT_MESSAGE="Sync ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"

FORCE_EXTERNAL=false
FORCE_LOCAL=false

case "$1" in
    --force-external)
        FORCE_EXTERNAL=true
        echo "=> Iniciando en modo: FORZAR EXTERNO"
        ;;
    --force-local)
        FORCE_LOCAL=true
        echo "=> Iniciando en modo: FORZAR LOCAL"
        ;;
    *)
        echo "=> Iniciando en modo: Sincronización normal"
        ;;
esac

if ! [[ -d "$SHARED_DIR" ]]; then
    rsync -av --exclude ".git/" "$REPO_DIR/" "$SHARED_DIR/"
fi

rsync -av --delete --exclude ".git/" "$SHARED_DIR/" "$REPO_DIR/"

cd "$REPO_DIR"

python3 "$HOME/scripts/update-todos.py" "$REPO_DIR"

if [ "$FORCE_EXTERNAL" = true ]; then
    echo "[F-EXT] Forzando remoto. Destruyendo cambios locales..."

    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    git checkout main >/dev/null 2>&1 || true

    git fetch origin main

    git reset --hard origin/main

    git clean -fd

elif [ "$FORCE_LOCAL" = true ]; then
    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    git checkout main >/dev/null 2>&1 || true
    git add -A
    git commit -m "$COMMIT_MESSAGE" || true
    git push origin main --force
else
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "$COMMIT_MESSAGE"
    fi
    git pull --rebase --autostash origin main
    git push origin main
fi

rsync -av --delete --exclude ".git/" "$REPO_DIR/" "$SHARED_DIR/"

echo "Sincronización completada con éxito."
