#!/bin/bash
# FloatingTodo 설치 스크립트
#   curl -fsSL https://raw.githubusercontent.com/ZaMan0806/FloatingTodo/main/install.sh | bash
# 소스를 받아 이 맥에서 직접 빌드하고, 로그인 시 자동 실행되도록 등록합니다.
set -euo pipefail

REPO="ZaMan0806/FloatingTodo"
BRANCH="main"
LABEL="com.zaman.floatingtodo"
APPDIR="$HOME/Library/Application Support/FloatingTodo"
BIN="$APPDIR/FloatingTodo"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31m오류:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "macOS 에서만 설치할 수 있어요."
MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[ "$MAJOR" -ge 13 ] || fail "macOS 13 Ventura 이상이 필요해요. (현재 $(sw_vers -productVersion))"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  say "Swift 컴파일러(Xcode Command Line Tools)가 필요해요. 설치 창을 띄웁니다."
  xcode-select --install 2>/dev/null || true
  fail "설치가 끝나면 같은 명령어를 다시 실행해 주세요."
fi

# 소스 위치: 저장소 안에서 실행했으면 그 폴더, 아니면 GitHub 에서 내려받기
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$DIR/Sources/main.swift" ] && SRC="$DIR"
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
if [ -z "$SRC" ]; then
  say "소스 내려받는 중... ($REPO@$BRANCH)"
  curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" \
    | tar -xz -C "$WORK" --strip-components=1
  SRC="$WORK"
fi

say "빌드 중... (처음엔 1분 정도 걸릴 수 있어요)"
xcrun swiftc -O "$SRC/Sources/main.swift" -o "$WORK/FloatingTodo" \
  -framework AppKit -framework SwiftUI \
  || fail "빌드에 실패했어요. 위 오류와 함께 이슈를 남겨 주세요: https://github.com/$REPO/issues"

mkdir -p "$APPDIR" "$HOME/Library/LaunchAgents"

# 예전 버전(프로젝트 폴더에 todos.json 저장)에서 옮겨오기
if [ -f "$SRC/todos.json" ] && [ ! -f "$APPDIR/todos.json" ]; then
  cp "$SRC/todos.json" "$APPDIR/todos.json"
  say "기존 할 일을 새 저장 위치로 옮겼어요."
fi

say "설치 중..."
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
pkill -x FloatingTodo 2>/dev/null || true
sleep 0.5
cp "$WORK/FloatingTodo" "$BIN"

# 로그인 시 자동 실행 (오류로 꺼지면 다시 켜고, 메뉴에서 '종료'하면 다음 로그인까지 꺼진 채로)
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$BIN</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key>
  <dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST

if launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; then
  say "완료! 화면에 떠다니는 버튼이 생겼어요. 로그인할 때마다 자동으로 켜집니다."
else
  nohup "$BIN" >/dev/null 2>&1 &
  disown || true
  say "실행했어요. (자동 실행 등록은 실패했어요)"
fi
echo "    삭제: curl -fsSL https://raw.githubusercontent.com/$REPO/$BRANCH/uninstall.sh | bash"
