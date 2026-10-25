#!/bin/bash
# 지금 실행 중인 것만 끄기 (다음 로그인 때는 다시 자동 실행됨)
launchctl bootout "gui/$(id -u)/com.zaman.floatingtodo" 2>/dev/null
pkill -x FloatingTodo 2>/dev/null
echo "종료했어요."
