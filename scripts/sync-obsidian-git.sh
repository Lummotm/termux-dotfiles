#!/usr/bin/env bash
set -e
# Termux toast clogs the system
source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="mobile"
REPO_DIR="$HOME/obsidian"
SHARED_DIR="$HOME/storage/shared/obsidian"

COMMIT_MESSAGE="Sync ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"

FORCE_LOCAL=false
FORCE_EXTERNAL=false

for arg in "$@"; do
    if [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
        FORCE_LOCAL=true
    elif [[ "$arg" == "-fe" || "$arg" == "--force-external" ]]; then
        FORCE_EXTERNAL=true
    fi
done

rsync -av --update "$SHARED_DIR/" "$REPO_DIR/"

cd "$REPO_DIR"

if [ "$FORCE_EXTERNAL" = true ]; then
    echo "Forzando actualización desde el servidor..."
    git fetch origin main
    git reset --hard origin/main
    # Después del reset, el rsync final se encargará de llevarlo a SHARED_DIR
elif [ "$FORCE_LOCAL" = true ]; then
    git add -A
    git commit -m "$COMMIT_MESSAGE" || true
    git push origin main --force
else
    # Tu flujo normal de pull/push
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "$COMMIT_MESSAGE"
    fi
    git pull --rebase --autostash -Xours origin main
    git push origin main
fi

# Post-procesado y actualización de la UI de Obsidian
python3 "$HOME/scripts/update-todos.py" "$REPO_DIR"

# Importante: rsync con --delete solo al final para que el móvil vea lo que bajó de Git
rsync -avu --delete --exclude ".git/" "$REPO_DIR/" "$SHARED_DIR/"
