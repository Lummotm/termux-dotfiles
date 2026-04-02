#!/usr/bin/env bash
echo "--- Sincronizando Obsidian ---"
bash ~/scripts/sync-obsidian-git.sh
echo ""

echo "--- Sincronizando KeePass ---"
bash ~/scripts/sync-keepass-phone.sh
echo ""
