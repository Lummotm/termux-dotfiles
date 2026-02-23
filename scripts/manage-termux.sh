#!/usr/bin/env bash

termux-setup-storage

pkg update -y && pkg upgrade -y
pkg install -y git openssh termux-api ncurses-utils fish neovim

mkdir -p "$HOME/scripts" "$HOME/logs" "$HOME/.config/fish"

# Copia scripts (asumiendo que están en carpeta ./scripts/ al ejecutar esto)
cp scripts/manage-termux.sh "$HOME/scripts/"
cp scripts/sync-git "$HOME/scripts/"
chmod +x "$HOME/scripts/"*

# SSH Key
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519"
    ssh-keyscan -t ed25519 github.com >>"$HOME/.ssh/known_hosts" 2>/dev/null
    cat "$HOME/.ssh/id_ed25519.pub" | termux-clipboard-set 2>/dev/null
    echo "Key copiada al clipboard."
fi

# Config Fish
FISH_CFG="$HOME/.config/fish/config.fish"

grep -q "EDITOR nvim" "$FISH_CFG" || echo "set -gx EDITOR nvim" >>"$FISH_CFG"
grep -q "alias vim=nvim" "$FISH_CFG" || echo "alias vim=nvim" >>"$FISH_CFG"
grep -q "alias nano=nvim" "$FISH_CFG" || echo "alias nano=nvim" >>"$FISH_CFG"

# Auto-start sync
if ! grep -q "manage-termux.sh" "$FISH_CFG"; then
    echo "bash $HOME/scripts/manage-termux.sh" >>"$FISH_CFG"
fi

chsh -s fish
