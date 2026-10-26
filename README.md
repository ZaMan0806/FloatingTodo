# FloatingTodo

macOS 화면 위에 항상 떠 있는 버튼 하나로 할 일을 관리하는 작은 앱입니다.
버튼을 누르면 옆에 할 일 패널이 열립니다.

## 기능

- 항상 다른 창 위에 떠 있는 버튼 (드래그로 이동, 모든 데스크톱·전체화면에서 표시)
- 할 일 + 체크포인트(하위 단계) 생성 · 수정 · 삭제, 체크포인트 안에 또 체크포인트 (3단계까지)
- 손잡이(≡)를 끌어서 할 일·체크포인트 순서 바꾸기
- 퍼스널 컬러 설정 (체크 표시와 버튼 색에 적용)
- macOS 26 에서는 Liquid Glass 디자인
- 패널 크기 조절, 로그인 시 자동 실행, 자동 저장
- 새 버전이 올라오면 알려 주고 버튼 한 번으로 업데이트

## 설치

터미널에 붙여 넣으세요.

```bash
curl -fsSL https://raw.githubusercontent.com/ZaMan0806/FloatingTodo/main/install.sh | bash
```

소스를 내려받아 **내 맥에서 직접 빌드**한 뒤 설치합니다.
같은 명령어를 다시 실행하면 최신 버전으로 업데이트됩니다.

**필요한 것**
- macOS 13 Ventura 이상 (Liquid Glass 는 macOS 26 + Xcode 26 Command Line Tools)
- Xcode Command Line Tools — 없으면 설치 창이 뜹니다. 설치 후 명령어를 다시 실행하세요.

## 사용법

| 동작 | 방법 |
| --- | --- |
| 패널 열기 / 닫기 | 버튼 클릭 |
| 버튼 옮기기 | 버튼 드래그 |
| 할 일 추가 | 패널 위쪽 `+` |
| 체크포인트 추가 | 할 일 줄의 `⊕` |
| 하위 체크포인트 추가 | 체크포인트 줄의 `⊕` |
| 수정 | 텍스트 클릭 |
| 순서 바꾸기 | 할 일·체크포인트 왼쪽 `≡` 를 위아래로 끌기 (체크포인트는 같은 단계 안에서, 하위 체크포인트와 함께 이동) |
| 퍼스널 컬러 | 패널 위쪽 `⚙︎` |
| 패널 크기 | 아래쪽 모서리 손잡이 끌기 |
| 업데이트 | 패널 위쪽 `업데이트` 버튼, 또는 버튼 우클릭 → 업데이트 확인 |
| 종료 | 버튼 우클릭 → 종료 (다음 로그인 때 다시 켜짐) |

할 일은 `~/Library/Application Support/FloatingTodo/todos.json` 에 저장됩니다.

## 업데이트

앱이 켜질 때, 한 시간마다, 패널을 열 때(10분에 한 번까지), 잠자기에서 깨어난 뒤 GitHub 의 `main` 브랜치를 확인합니다.
새 버전이 있으면 버튼에 빨간 점이 생기고 패널 위쪽에 `업데이트` 버튼이 나타납니다.
누르면 새 소스를 받아 빌드한 뒤 앱이 잠깐 꺼졌다가 다시 켜집니다. 할 일은 그대로 남아요.

- 업데이트 기록: `~/Library/Application Support/FloatingTodo/update.log`
- 직접 빌드(`./install.sh`)로 설치한 경우에는 업데이트 알림이 뜨지 않습니다.

## 삭제

```bash
curl -fsSL https://raw.githubusercontent.com/ZaMan0806/FloatingTodo/main/uninstall.sh | bash
```

할 일 데이터까지 지우려면:

```bash
curl -fsSL https://raw.githubusercontent.com/ZaMan0806/FloatingTodo/main/uninstall.sh | bash -s -- --purge
```

## 직접 빌드 (개발)

```bash
git clone https://github.com/ZaMan0806/FloatingTodo.git
cd FloatingTodo
./install.sh
```

Xcode 에서 `Package.swift` 를 열면 파일 사이 이동·자동 완성이 됩니다.

### 코드 구조

```
Sources/
├── main.swift                  앱 시작
├── App/AppDelegate.swift       버튼·패널 창 관리, 우클릭 메뉴
├── Model/                      데이터 (할 일·체크포인트, 저장, 퍼스널 컬러)
├── Update/Updater.swift        업데이트 확인·설치
├── Views/
│   ├── Panel/                  할 일 패널, 카드, 설정, 업데이트 안내
│   ├── Editor/                 여러 줄 입력칸 (NSTextView)
│   └── Components/             공통 버튼, 끌어서 순서 바꾸는 목록, Liquid Glass 배경
└── Windows/                    떠 있는 창, 동그란 버튼, 크기 조절 손잡이
```

## 라이선스

MIT
