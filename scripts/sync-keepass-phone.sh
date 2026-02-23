#!/usr/bin/env bash
set -e
source ~/.termux_device_info 2>/dev/null || TERMUX_DEVICE_NAME="móvil"

repo="$HOME/keepass"
shared="$HOME/storage/shared/keepass/"

check_connection() {
    if ! git ls-remote "$repo" >/dev/null 2>&1; then
        echo "⚠️ Error: No hay conexión con el repositorio remoto o falta la clave SSH."
        echo "Sincronización abortada."
        exit 1
    fi
}
check_connection

mkdir -p "$shared"

echo " 1. Sincronizando desde carpeta del móvil al repositorio (solo archivos más recientes)..."
rsync -avu "$shared/" "$repo/"

echo "🔧 2. Commit de cambios si los hay..."
cd "$repo"
git add -A

if ! git diff --cached --quiet; then
    fecha=$(date '+%Y-%m-%d %H:%M')
    git commit -m "Sync desde $TERMUX_DEVICE_NAME $fecha"
    echo " Commit creado."
else
    echo " No hay cambios para commitear."
fi

echo " 3. Actualizando con git pull (con rebase)..."
git pull --rebase

echo " 4. Enviando los cambios al remoto..."
git push

echo " 5. Copiando repo final → carpeta visible por Keepass..."
mkdir -p "$shared"
rsync -av --delete "$repo/" "$shared/"

echo " Sincronización completa entre Keepass móvil y Git."
