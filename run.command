#!/bin/bash
# 더블클릭: 이 폴더의 소스로 빌드 → 설치 → 실행 (개발용)
cd "$(dirname "$0")" || exit 1
bash ./install.sh || read -n 1 -s -r -p "아무 키나 누르면 닫힙니다"
