#!/usr/bin/env bash
set -e
# Termux toast clogs the system
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

# Gestión de cambios
git add -A
if ! git diff --cached --quiet; then
    git commit -m "$COMMIT_MESSAGE"
fi

if [ "$FORCE_LOCAL" = true ]; then
    git fetch origin
    git push origin main --force
else
    # El pull rebase con autostash es lo más seguro para no perder notas
    if ! git pull --rebase --autostash origin main; then
        git rebase --abort
        exit 1
    fi
    git push origin main
fi

# Post-procesado y actualización de la UI de Obsidian
python3 "$HOME/scripts/update-todos.py" "$REPO_DIR"

# Importante: rsync con --delete solo al final para que el móvil vea lo que bajó de Git
rsync -avu --delete --exclude ".git/" "$REPO_DIR/" "$SHARED_DIR/"
