#!/bin/bash
set -e

echo "🚀 Sandboxdocker 설치 및 실행 스크립트"
echo ""

# 사용 방법 선택
echo "사용 방법을 선택하세요:"
echo "  1) Docker Hub에서 자동 pull (권장, 빠름)"
echo "  2) GitHub Release에서 tar 파일 다운로드 (오프라인 가능)"
echo ""
read -p "선택 (1 또는 2, 기본값: 1): " choice
choice=${choice:-1}

if [ "$choice" = "2" ]; then
  echo ""
  echo "📦 GitHub Release 방식 선택됨"
  echo ""
  
  # 1) tar와 compose 파일 받기
  echo "⬇️  파일 다운로드 중..."
  wget -q --show-progress https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/sandboxdocker.tar
  
  # 2) 이미지 로드
  echo "📂 이미지 로드 중..."
  docker load -i sandboxdocker.tar
  
  # 3) 이미지 태그 변경 (docker-compose.yml과 일치시키기)
  echo "🏷️  이미지 태그 설정 중..."
  docker tag sandboxdocker:latest evolve1/sandboxdocker:latest
  
  # 4) tar 파일 삭제 (옵션)
  rm -f sandboxdocker.tar
  echo "✅ 이미지 준비 완료!"
else
  echo ""
  echo "🐳 Docker Hub 방식 선택됨 (권장)"
  echo ""
fi

# docker-compose.yml 다운로드
echo "⬇️  docker-compose.yml 다운로드 중..."
wget -q --show-progress -O docker-compose.yml https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/docker-compose.yml

# 컨테이너 실행 (Docker Hub 방식이면 자동으로 pull)
echo ""
echo "🚢 컨테이너 실행 중..."
docker compose up -d

echo ""
echo "✅ 완료! 컨테이너가 실행되었습니다."
echo ""
echo "📍 컨테이너 접속:"
echo "   docker compose exec sandboxdocker bash"
echo ""
echo "📍 컨테이너 중지:"
echo "   docker compose down"
echo ""

# 컨테이너 접속 (시작 위치: /root/ext_volume)
read -p "지금 컨테이너에 접속하시겠습니까? (y/N): " connect
if [ "$connect" = "y" ] || [ "$connect" = "Y" ]; then
  docker compose exec sandboxdocker bash
fi
