#!/usr/bin/env bash

set -e

# Configuración de variables
source ~/.termux_device_info 2>/dev/null || TERMUX_DEVICE_NAME="móvil"
repo="$HOME/obsidian"
shared="$HOME/storage/shared/obsidian"
FORCE_LOCAL=false

# 0. Verificar si se pasó la flag de prioridad
for arg in "$@"; do
    if [ "$arg" == "-f" ] || [ "$arg" == "--force" ]; then
        FORCE_LOCAL=true
        echo " MODO PRIORIDAD LOCAL ACTIVADO"
    fi
done

cd "$repo"

# 1. Sincronizar desde la carpeta de Obsidian al repo local
echo " 1. Importando cambios desde Obsidian..."
rsync -avu "$shared/" "$repo/"

# 2. Commit de cambios
echo " 2. Preparando commit..."
git add -A
if ! git diff --cached --quiet; then
    fecha=$(date '+%Y-%m-%d %H:%M')
    git commit -m "Sync ($TERMUX_DEVICE_NAME) $fecha"
fi

# 3. Sincronización de red
echo " 3. Sincronizando con el servidor..."
if [ "$FORCE_LOCAL" = true ]; then
    # En modo fuerza, descargamos lo de fuera pero priorizamos lo nuestro
    git fetch origin
    # Forzamos que nuestra rama local sea la dominante
    git push origin main --force
else
    # Modo normal: intenta mezclar suavemente
    git pull --rebase origin main || {
        echo " Conflicto detectado. Limpiando..."
        git rebase --abort
        exit 1
    }
    git push origin main
fi

# 4. Actualizar la carpeta compartida (la que ve la App)
echo " 4. Reflejando cambios finales en Obsidian..."
rsync -av --delete "$repo/" "$shared/"

echo " Sincronización terminada."
