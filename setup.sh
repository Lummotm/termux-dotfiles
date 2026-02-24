#!/usr/bin/env bash
set -e

echo "Iniciando configuración de Termux..."

# 1. Información del dispositivo
if [ ! -f ~/.termux_device_info ]; then
    read -p "Introduce el nombre para este dispositivo (ej. movil-personal): " DISP_NAME
    echo "export TERMUX_DEVICE_NAME='$DISP_NAME'" >~/.termux_device_info
    echo "Nombre del dispositivo guardado."
else
    source ~/.termux_device_info
    echo "Dispositivo ya configurado como: $TERMUX_DEVICE_NAME"
fi

# 2. Instalación de paquetes (solo si no están)
read -p "¿Quieres actualizar?(si/no) (default no)" UPDATE
if [[ "$UPDATE" == "si" ]]; then
    echo "Actualizando y verificando paquetes..."
    pkg update && pkg upgrade -y
    pkg install fish neovim git rsync openssh termux-api starship -y
fi

# 3. Directorios base
mkdir -p ~/.config/fish ~/scripts ~/keepass ~/obsidian

# 4. Configuración de Git (solo si no existe)
CURRENT_GIT_USER=$(git config --global user.name || true)
if [ -z "$CURRENT_GIT_USER" ]; then
    read -p "Introduce tu email de GitHub: " GIT_EMAIL
    read -p "Introduce tu nombre de GitHub: " GIT_USER
    git config --global user.email "$GIT_EMAIL"
    git config --global user.name "$GIT_USER"
else
    echo "Git ya está configurado para: $CURRENT_GIT_USER"
fi

# 5. Configuración de SSH (Verifica si ya tienes llaves)
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "No se encontró llave SSH. Generando una nueva..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
    echo "Llave generada. Esta es tu llave pública para GitHub:"
    cat ~/.ssh/id_ed25519.pub
else
    echo "Llave SSH detectada en ~/.ssh/id_ed25519"
fi

# 6. Gestión de archivos y scripts
# Usamos -u en cp para actualizar solo si el origen es más reciente
[ -f bashrc ] && cp -u bashrc ~/.bashrc
[ -d fish ] && cp -ru fish/* ~/.config/fish/
[ -d scripts ] && cp -u scripts/*.sh ~/scripts/

if ! grep -q "termux_device_info" ~/.bashrc; then
    echo "source ~/.termux_device_info" >>~/.bashrc
fi
chmod +x ~/scripts/*.sh

# 7. Almacenamiento y Carpetas compartidas
if [ ! -d ~/storage/shared ]; then
    termux-setup-storage
fi

# Copia de seguridad solo si la carpeta original existe y no hay copia previa
if [ -d ~/storage/shared/obsidian ] && [ ! -d ~/storage/shared/obsidian-copia ]; then
    echo "Creando copia de seguridad de Obsidian..."
    cp -r ~/storage/shared/obsidian ~/storage/shared/obsidian-copia
    rm -rf ~/storage/shared/obsidian
    mkdir -p ~/storage/shared/obsidian
fi

mkdir -p ~/storage/shared/keepass

echo "Configuración completada con éxito."
