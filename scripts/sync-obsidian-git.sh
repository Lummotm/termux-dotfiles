#!/usr/bin/env bash
set -e

# Configuración
source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="mobile"
REPO_DIR="$HOME/obsidian"
SHARED_DIR="$HOME/storage/shared/obsidian"
FORCE_LOCAL=false

# Argumentos
for arg in "$@"; do
    if [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
        FORCE_LOCAL=true
        echo "FORCING LOCAL"
    fi
done

cd "$REPO_DIR"

echo "1. Importando: Shared -> Repo local"
# --delete para reflejar borrados hechos en el móvil
rsync -av --delete "$SHARED_DIR/" "$REPO_DIR/"

echo "2. Gestionando cambios en git"
git add -A
if ! git diff --cached --quiet; then
    git commit -m "Sync ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"
fi

echo "3. Sincronizando con remoto"
if [ "$FORCE_LOCAL" = true ]; then
    git fetch origin
    git push origin main --force
else
    # Rebase favoreciendo cambios locales en conflicto
    git pull --rebase --autostash -X theirs origin main || {
        echo "Error en rebase. Abortando."
        git rebase --abort
        exit 1
    }
    git push origin main
fi

echo "4. Exportando: Repo local -> Shared"
# -u para no sobrescribir si algo cambió en shared durante el proceso (poco probable pero seguro)
rsync -avu "$REPO_DIR/" "$SHARED_DIR/"

echo "Sincronización Obsidian finalizada."
