#!/usr/bin/env bash
echo "--- Sincronizando Obsidian ---"
bash ~/scripts/sync-obsidian-git.sh "$1"
echo ""

echo "--- Sincronizando KeePass ---"
bash ~/scripts/sync-keepass-phone.sh "$1"
