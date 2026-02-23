#!/usr/bin/env bash
set -e

echo "Iniciando configuración de Termux..."

read -p "Introduce el nombre para este dispositivo (ej. movil-personal): " DISP_NAME
echo "export TERMUX_DEVICE_NAME='$DISP_NAME'" >~/.termux_device_info
echo "Nombre del dispositivo guardado como: $DISP_NAME"

pkg update && pkg upgrade -y
pkg install fish neovim git rsync openssh termux-api starship -y

mkdir -p ~/.config/fish
mkdir -p ~/scripts
mkdir -p ~/keepass
mkdir -p ~/obsidian

cp bashrc ~/.bashrc
cp fish/config.fish ~/.config/fish/config.fish
cp scripts/*.sh ~/scripts/

if ! grep -q "termux_device_info" ~/.bashrc; then
    echo "source ~/.termux_device_info" >>~/.bashrc
fi

chmod +x ~/scripts/*.sh

termux-setup-storage

read -p "Introduce tu email de GitHub: " GIT_EMAIL
read -p "Introduce tu nombre de GitHub: " GIT_USER

git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_USER"

echo "Configuración completada."
