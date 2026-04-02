#!/usr/bin/env bash
set -e
source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="mobile"

# Definimos rutas limpias (sin barra al final aquí)
REPO_DIR="$HOME/obsidian"
SHARED_DIR="$HOME/storage/shared/obsidian"

COMMIT_MESSAGE="Sync ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"

# --- EXPLICACIÓN DEL FIX ---
# "${VAR%/}/" es un truco de Bash que quita cualquier barra al final (si la hay)
# y añade EXACTAMENTE una. Esto asegura que rsync siempre vea "carpeta/"
# y sincronice el CONTENIDO, no la carpeta en sí.

# 1. Sincronizar de Android Shared -> Git Repo
rsync -a --delete --exclude ".git/" "${SHARED_DIR%/}/" "${REPO_DIR%/}/"

cd "$REPO_DIR"

if [ "$FORCE_EXTERNAL" = true ]; then
    echo "F-EXT: Forzando actualización desde el servidor..."
    git add -A
    git commit -m "Backup antes de F-EXT" || true
    git fetch origin main
    git reset --hard origin/main
elif [ "$FORCE_LOCAL" = true ]; then
    echo "F-LOC: Limpiando bloqueos y forzando local..."
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

# Procesar To-Dos
python3 "$HOME/scripts/update-todos.py" "$REPO_DIR"

# 2. Sincronizar de Git Repo -> Android Shared
# Usamos la misma lógica de blindaje con "${VAR%/}/"
rsync -a --delete --exclude ".git/" "${REPO_DIR%/}/" "${SHARED_DIR%/}/"
