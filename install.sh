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
UPDATER="$LABEL.updater"
UPDATER_PLIST="$HOME/Library/LaunchAgents/$UPDATER.plist"
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
SHA=""   # 설치하는 커밋. 앱이 이 값과 GitHub 의 최신 커밋을 비교해 업데이트를 알려 줌
if [ -z "$SRC" ]; then
  SHA=$(git ls-remote "https://github.com/$REPO.git" "refs/heads/$BRANCH" 2>/dev/null | cut -f1 || true)
  [[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || SHA=""
  say "소스 내려받는 중... ($REPO@${SHA:-$BRANCH})"
  curl -fsSL "https://github.com/$REPO/archive/${SHA:-refs/heads/$BRANCH}.tar.gz" \
    | tar -xz -C "$WORK" --strip-components=1
  SRC="$WORK"
fi

say "빌드 중... (처음엔 1분 정도 걸릴 수 있어요)"
# Sources 아래의 .swift 파일 전부 (하위 폴더 포함)
SWIFT_FILES=()
while IFS= read -r f; do SWIFT_FILES+=("$f"); done < <(find "$SRC/Sources" -name '*.swift' | sort)
xcrun swiftc -O -module-name FloatingTodo "${SWIFT_FILES[@]}" -o "$WORK/FloatingTodo" \
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
# 직접 빌드한 경우엔 버전을 지워서 업데이트 알림이 뜨지 않게
if [ -n "$SHA" ]; then echo "$SHA" > "$APPDIR/version"; else rm -f "$APPDIR/version"; fi

# 앱의 '업데이트' 버튼이 실행하는 작업. 앱과 따로 돌아야 위에서 앱을 끌 때 같이 꺼지지 않음
# (그 작업 안에서 이 스크립트가 돌고 있을 때는 자기 자신을 끄지 않도록 건너뜀)
if [ -z "${FT_UPDATING:-}" ]; then
  launchctl bootout "$DOMAIN/$UPDATER" 2>/dev/null || true
  cat > "$UPDATER_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$UPDATER</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>exec >"\$0/update.log" 2>&amp;1; set -o pipefail; curl -fsSL "https://raw.githubusercontent.com/$REPO/$BRANCH/install.sh" | FT_UPDATING=1 bash || touch "\$0/update-failed"</string>
    <string>$APPDIR</string>
  </array>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST
  launchctl bootstrap "$DOMAIN" "$UPDATER_PLIST" 2>/dev/null || true
fi

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
