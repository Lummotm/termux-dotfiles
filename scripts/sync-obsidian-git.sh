#!/usr/bin/env bash

set -e

source ~/.termux_device_info 2>/dev/null || TERMUX_DEVICE_NAME="móvil"

repo="$HOME/obsidian"
shared="$HOME/storage/shared/obsidian"
max_retries=3
retry_delay=5

# Función para manejar errores de Git
handle_git_error() {
    echo " Error detectado en operación Git. Limpiando estado..."
    cd "$repo"
    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    git reset --hard >/dev/null 2>&1
    git clean -fd >/dev/null 2>&1
    echo " Estado de Git limpiado."
}

# 1. Sincronizar desde móvil al repositorio
echo " 1. Sincronizando desde carpeta del móvil al repositorio..."
rsync -avu "$shared/" "$repo/"

# 2. Commit de cambios locales
echo " 2. Commit de cambios locales..."
cd "$repo"
git add -A

if ! git diff --cached --quiet; then
    fecha=$(date '+%Y-%m-%d %H:%M')
    git commit -m "Sync desde $TERMUX_DEVICE_NAME $fecha" || {
        echo " Falló el commit. Limpiando y continuando..."
        handle_git_error
        exit 1
    }
    echo " Commit creado."
else
    echo " No hay cambios para commitear."
fi

# 3. Actualizar con git pull (con estrategia más robusta)
echo " 3. Actualizando repositorio..."
retry_count=0
while [ $retry_count -lt $max_retries ]; do
    if git pull --rebase; then
        break
    else
        retry_count=$((retry_count + 1))
        echo " Falló git pull --rebase (intento $retry_count/$max_retries)"
        handle_git_error
        if [ $retry_count -lt $max_retries ]; then
            echo " Esperando $retry_delay segundos antes de reintentar..."
            sleep $retry_delay
        else
            echo " Usando estrategia alternativa: git reset --hard origin/main"
            git fetch origin
            git reset --hard origin/main
        fi
    fi
done

# 4. Enviar cambios al remoto
echo " 4. Enviando los cambios al remoto..."
if ! git push; then
    echo " Falló git push. Probando con --force-with-lease..."
    git push --force-with-lease || {
        echo " Error crítico al enviar cambios. Necesita intervención manual."
        handle_git_error
        exit 1
    }
fi

# 5. Copiar repo final a carpeta de Obsidian
echo " 5. Copiando repo final → carpeta visible por Obsidian..."
mkdir -p "$shared"
rsync -av --delete "$repo/" "$shared/"

echo " Sincronización completa entre Obsidian móvil y Git."
