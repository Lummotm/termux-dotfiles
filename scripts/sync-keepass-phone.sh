#!/usr/bin/env bash
set -e

# Configuración
source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="móvil"
REPO_DIR="$HOME/keepass"
SHARED_DIR="$HOME/storage/shared/keepass"

# Verificar conexión antes de empezar
if ! git ls-remote "$REPO_DIR" >/dev/null 2>&1; then
    echo "Error: Sin conexión al repositorio remoto."
    exit 1
fi

mkdir -p "$SHARED_DIR"

echo "1. Sincronizando: Móvil -> Repo local"
# -u para actualizar solo si el origen es más nuevo
rsync -avu "$SHARED_DIR/" "$REPO_DIR/"

echo "2. Gestionando cambios en git"
cd "$REPO_DIR"
git add -A

if ! git diff --cached --quiet; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
    git commit -m "Sync desde $TERMUX_DEVICE_NAME $TIMESTAMP"
    echo "Cambios confirmados."
else
    echo "Sin cambios pendientes."
fi

echo "3. Actualizando desde remoto (pull --rebase)"
git pull --rebase

echo "4. Subiendo cambios (push)"
git push

echo "5. Sincronizando: Repo local -> Móvil"
# --delete asegura que el móvil sea un espejo exacto del estado final del repo
mkdir -p "$SHARED_DIR"
rsync -av --delete "$REPO_DIR/" "$SHARED_DIR/"

echo "Sincronización Keepass finalizada."
