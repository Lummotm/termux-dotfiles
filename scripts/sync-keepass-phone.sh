#!/usr/bin/env bash
set -e

source "$HOME/.termux_device_info" 2>/dev/null || TERMUX_DEVICE_NAME="móvil"
REPO_DIR="$HOME/keepass"
SHARED_DIR="$HOME/storage/shared/keepass"

FORCE_EXTERNAL=false
FORCE_LOCAL=false

case "$1" in
--force-external)
  FORCE_EXTERNAL=true
  echo "=> Iniciando KeePass en modo: FORZAR EXTERNO"
  ;;
--force-local)
  FORCE_LOCAL=true
  echo "=> Iniciando KeePass en modo: FORZAR LOCAL"
  ;;
*)
  echo "=> Iniciando KeePass en modo: Sincronización normal"
  ;;
esac

rsync -a --delete "$SHARED_DIR/" "$REPO_DIR/"

cd "$REPO_DIR"

if [ "$FORCE_EXTERNAL" = true ]; then
  echo "[F-EXT] Forzando remoto en KeePass. Destruyendo cambios locales..."
  git rebase --abort >/dev/null 2>&1 || true
  git fetch origin main
  git reset --hard origin/main
  git clean -fd

elif [ "$FORCE_LOCAL" = true ]; then
  echo "[F-LOC] Forzando local en KeePass. Aplastando el remoto..."
  git rebase --abort >/dev/null 2>&1 || true
  git add -A
  git commit -m "Sync KeePass Forzado ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')" || true
  git push origin main --force

else
  git rebase --abort >/dev/null 2>&1 || true
  git add -A
  if ! git diff --cached --quiet; then
    git commit -m "Sync KeePass ($TERMUX_DEVICE_NAME) $(date '+%Y-%m-%d %H:%M')"
  fi

  # Gana el pc en pull
  if ! git pull --rebase -Xtheirs origin main; then
    echo "Conflicto binario detectado, forzando versión del servidor..."
    git rebase --abort
    git fetch origin main
    git reset --hard origin/main
  fi

  git push origin main
fi

rsync -a --delete "$REPO_DIR/" "$SHARED_DIR/"
