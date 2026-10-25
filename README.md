# FloatingTodo

macOS 화면 위에 항상 떠 있는 버튼 하나로 할 일을 관리하는 작은 앱입니다.
버튼을 누르면 옆에 할 일 패널이 열립니다.

## 기능

- 항상 다른 창 위에 떠 있는 버튼 (드래그로 이동, 모든 데스크톱·전체화면에서 표시)
- 할 일 + 체크포인트(하위 단계) 생성 · 수정 · 삭제
- 손잡이(≡)를 끌어서 할 일 순서 바꾸기
- 퍼스널 컬러 설정 (체크 표시와 버튼 색에 적용)
- macOS 26 에서는 Liquid Glass 디자인
- 패널 크기 조절, 로그인 시 자동 실행, 자동 저장

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
| 수정 | 텍스트 클릭 |
| 순서 바꾸기 | 왼쪽 `≡` 를 위아래로 끌기 |
| 퍼스널 컬러 | 패널 위쪽 `⚙︎` |
| 패널 크기 | 아래쪽 모서리 손잡이 끌기 |
| 종료 | 버튼 우클릭 → 종료 (다음 로그인 때 다시 켜짐) |

할 일은 `~/Library/Application Support/FloatingTodo/todos.json` 에 저장됩니다.

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

## 라이선스

MIT
