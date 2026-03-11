#!/usr/bin/env bash
set -e

# Paquetes a instalar
PACKAGES=(
    fish
    neovim
    git
    rsync
    openssh
    termux-api
    starship
    python
)

# Modo sincronización de archivos de configuración
for arg in "$@"; do
    if [ "$arg" == "--sync" ]; then
        cd ~/termux-dotfiles
        git pull origin main
        [ -f bashrc ] && cp -u bashrc ~/.bashrc
        [ -d fish ] && cp -ru fish/* ~/.config/fish/
        [ -d scripts ] && cp -u scripts/* ~/scripts/
        [ -d termux ] && cp -ru termux/* ~/.termux/
        clear
        exec fish
    fi
done

echo "Iniciando configuración de Termux..."

# Identificación del dispositivo
if [ ! -f ~/.termux_device_info ]; then
    read -p "Introduce el nombre para este dispositivo (ej. movil-personal): " DISP_NAME
    echo "export TERMUX_DEVICE_NAME='$DISP_NAME'" >~/.termux_device_info
    echo "Nombre del dispositivo guardado."
else
    source ~/.termux_device_info
    echo "Dispositivo ya configurado como: $TERMUX_DEVICE_NAME"
fi

# Actualización e instalación de paquetes
read -p "¿Quieres actualizar paquetes? (si/no) [default: no]: " UPDATE
if [[ "$UPDATE" == "si" ]]; then
    echo "Actualizando y verificando paquetes..."
    pkg update && pkg upgrade -y
    pkg install "${PACKAGES[@]}" -y
    pkg autoclean -y
fi

mkdir -p ~/.config/fish ~/scripts ~/keepass ~/obsidian

# Configuración de usuario Git
CURRENT_GIT_USER=$(git config --global user.name || true)
if [ -z "$CURRENT_GIT_USER" ]; then
    read -p "Introduce tu email de GitHub: " GIT_EMAIL
    read -p "Introduce tu nombre de GitHub: " GIT_USER
    git config --global user.email "$GIT_EMAIL"
    git config --global user.name "$GIT_USER"
else
    GIT_EMAIL=$(git config --global user.email)
    echo "Git ya está configurado para: $CURRENT_GIT_USER"
fi

# Configuración de llaves SSH
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "No se encontró llave SSH. Generando una nueva..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
    echo "-------------------------------------------------------"
    echo "LLAVE PÚBLICA GENERADA. Cópiala y pégala en GitHub:"
    echo "https://github.com/settings/keys"
    echo "-------------------------------------------------------"
    cat ~/.ssh/id_ed25519.pub
    echo "-------------------------------------------------------"
    read -p "Presiona Enter cuando hayas añadido la llave a GitHub para continuar..." CONFIRM
else
    echo "Llave SSH detectada en ~/.ssh/id_ed25519"
fi

mkdir -p ~/.ssh
ssh-keyscan -t ed25519 github.com >>~/.ssh/known_hosts 2>/dev/null

# Permisos de almacenamiento en Android
if [ ! -d ~/storage/shared ]; then
    echo "Solicitando permisos de almacenamiento..."
    termux-setup-storage
    echo "POR FAVOR, acepta el permiso en el pop-up de tu pantalla."

    until [ -d ~/storage/shared ]; do
        sleep 1
    done
    echo "Permisos de almacenamiento concedidos."
fi

# Configuración del repositorio de Obsidian
OBSIDIAN_DIR="$HOME/obsidian"
REPO_URL="git@github.com:Lummotm/obsidian.git"

if [ ! -d "$OBSIDIAN_DIR/.git" ]; then
    echo "Configurando repositorio de Obsidian..."

    if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "❌ ERROR: No se pudo autenticar con GitHub. Revisa tu llave SSH."
        exit 1
    fi

    cd "$OBSIDIAN_DIR"
    if [ -z "$(ls -A .)" ]; then
        git clone "$REPO_URL" .
    else
        git init
        git remote add origin "$REPO_URL"
        git fetch origin
        git checkout -f main
    fi
else
    echo "Actualizando repositorio de Obsidian..."
    cd "$OBSIDIAN_DIR"
    git pull origin main
fi

# Aplicación final de configuraciones y cambio de shell
cd ~/termux-dotfiles
[ -f bashrc ] && cp -u bashrc ~/.bashrc
[ -d fish ] && cp -ru fish/* ~/.config/fish/
[ -d scripts ] && cp -u scripts/*.sh ~/scripts/

if ! grep -q "termux_device_info" ~/.bashrc; then
    echo "source ~/.termux_device_info" >>~/.bashrc
fi
chmod +x ~/scripts/*.sh

echo "✅ Configuración completada con éxito."
echo "Reiniciando en shell Fish..."
exec fish
