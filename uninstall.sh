#!/bin/bash
# FloatingTodo 삭제 스크립트
#   curl -fsSL https://raw.githubusercontent.com/ZaMan0806/FloatingTodo/main/uninstall.sh | bash
#   할 일 데이터까지 지우려면 끝에 -s -- --purge 를 붙이세요.
set -uo pipefail

LABEL="com.zaman.floatingtodo"
APPDIR="$HOME/Library/Application Support/FloatingTodo"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
launchctl bootout "gui/$(id -u)/$LABEL.updater" 2>/dev/null
pkill -x FloatingTodo 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist" "$HOME/Library/LaunchAgents/$LABEL.updater.plist"
rm -f "$APPDIR/FloatingTodo" "$APPDIR/version" "$APPDIR/update.log" "$APPDIR/update-failed"

if [ "${1:-}" = "--purge" ]; then
  rm -rf "$APPDIR"
  defaults delete FloatingTodo 2>/dev/null
  echo "FloatingTodo 와 할 일 데이터를 모두 삭제했어요."
else
  echo "FloatingTodo 를 삭제했어요. 할 일 데이터는 $APPDIR 에 남아 있어요. (todos.json, calendar.json)"
fi
