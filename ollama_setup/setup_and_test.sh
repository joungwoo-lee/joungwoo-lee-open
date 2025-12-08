#!/bin/bash

# Ollama 테스트 환경 구축 및 테스트 스크립트
# 이 스크립트는 다음을 수행합니다:
# 1. NVIDIA Container Toolkit 설치 (GPU 가속)
# 2. Docker Compose로 Ollama 컨테이너 실행
# 3. gpt-oss:20b 모델 다운로드 및 실행
# 4. 테스트 코드 실행

set -e  # 에러 발생시 스크립트 중단

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "=================================="
echo "Ollama 테스트 환경 설정 시작"
echo "=================================="
echo ""

# 1. Docker Compose 설치 확인 및 설치
echo "[1/7] Docker Compose 설치 확인 중..."
if ! docker compose version &> /dev/null; then
    echo "Docker Compose가 설치되어 있지 않습니다. 최신 버전 설치를 시작합니다..."

    # 시스템 아키텍처 확인
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            DOCKER_COMPOSE_ARCH="x86_64"
            ;;
        aarch64)
            DOCKER_COMPOSE_ARCH="aarch64"
            ;;
        armv7l)
            DOCKER_COMPOSE_ARCH="armv7"
            ;;
        *)
            echo "지원하지 않는 아키텍처입니다: $ARCH"
            exit 1
            ;;
    esac

    # Docker Compose 플러그인 디렉토리 생성
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins

    # 최신 버전 다운로드
    echo "최신 Docker Compose 다운로드 중..."
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${DOCKER_COMPOSE_ARCH}" -o $DOCKER_CONFIG/cli-plugins/docker-compose

    # 실행 권한 부여
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

    echo "Docker Compose ${COMPOSE_VERSION} 설치 완료"
    docker compose version
else
    echo "Docker Compose가 이미 설치되어 있습니다."
    docker compose version
fi
echo ""

# 2. NVIDIA Container Toolkit 설치 확인 및 설치
echo "[2/7] NVIDIA Container Toolkit 설치 확인 중..."
if ! command -v nvidia-ctk &> /dev/null; then
    echo "NVIDIA Container Toolkit이 설치되어 있지 않습니다. 설치를 시작합니다..."

    # GPG 키 다운로드
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
      sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

    # 레포지토리 추가
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    # 설치
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo service docker restart

    echo "NVIDIA Container Toolkit 설치 완료"
else
    echo "NVIDIA Container Toolkit이 이미 설치되어 있습니다."
fi
echo ""

# 3. GPU 테스트
echo "[3/7] GPU 접근 테스트 중..."
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi || {
    echo "경고: GPU 테스트에 실패했습니다. CPU 모드로 계속 진행합니다."
}
echo ""

# 4. 기존 컨테이너 정리 (선택사항)
echo "[4/7] 기존 Ollama 컨테이너 확인 중..."
if docker ps -a | grep -q ollama; then
    echo "기존 Ollama 컨테이너가 발견되었습니다. 제거하시겠습니까? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        docker compose down -v
        echo "기존 컨테이너가 제거되었습니다."
    fi
fi
echo ""

# 5. Docker Compose로 Ollama 실행
echo "[5/7] 최신 Ollama 이미지 다운로드 중..."
docker compose pull
echo "Docker Compose로 Ollama 컨테이너 시작 중..."
docker compose up -d
echo "Ollama 컨테이너가 시작되었습니다."
echo ""

# 6. 컨테이너가 완전히 시작될 때까지 대기
echo "[6/7] Ollama 서비스가 준비될 때까지 대기 중..."
sleep 10

# gpt-oss:20b 모델 다운로드 및 준비
echo "gpt-oss:20b 모델을 다운로드하고 준비합니다..."
echo "주의: 모델이 크므로 다운로드에 시간이 걸릴 수 있습니다."
docker exec ollama ollama pull gpt-oss:20b

# bge-m3:latest 임베딩 모델 다운로드 및 준비
echo ""
echo "bge-m3:latest 임베딩 모델을 다운로드하고 준비합니다..."
docker exec ollama ollama pull bge-m3:latest

echo ""
echo "모든 모델 준비가 완료되었습니다."
echo ""

# 7. Python 테스트 실행
echo "[7/7] Python 테스트 코드 실행 중..."
echo ""

# 테스트 1: OpenAI 라이브러리 테스트
echo "=================================="
echo "테스트 1: OpenAI 라이브러리 테스트"
echo "=================================="
echo "필요한 패키지 확인 중..."

# import 체크
if python3 -c "import openai; from dotenv import load_dotenv" 2>/dev/null; then
    echo "모든 필요한 패키지가 설치되어 있습니다."
    echo ""
    python3 test_openai.py
else
    echo ""
    echo "❌ 필요한 패키지가 설치되어 있지 않습니다."
    echo ""
    echo "다음 명령어로 설치하세요:"
    echo "  pip3 install python-dotenv openai"
    echo ""
    echo "테스트 1을 건너뜁니다."
fi
echo ""
echo ""

# 테스트 2: LangChain OpenAI 테스트
echo "=================================="
echo "테스트 2: LangChain OpenAI 테스트"
echo "=================================="
echo "필요한 패키지 확인 중..."

# import 체크
if python3 -c "from langchain_openai import ChatOpenAI; from dotenv import load_dotenv" 2>/dev/null; then
    echo "모든 필요한 패키지가 설치되어 있습니다."
    echo ""
    python3 test_langchain_openai.py
else
    echo ""
    echo "❌ 필요한 패키지가 설치되어 있지 않습니다."
    echo ""
    echo "다음 명령어로 설치하세요:"
    echo "  pip3 install python-dotenv langchain-openai"
    echo ""
    echo "테스트 2를 건너뜁니다."
fi
echo ""
echo ""

echo "=================================="
echo "모든 작업이 완료되었습니다!"
echo "=================================="
echo ""
echo "유용한 명령어:"
echo "  - 컨테이너 상태 확인: docker compose ps"
echo "  - 컨테이너 로그 확인: docker compose logs -f"
echo "  - Ollama 직접 실행: docker exec -it ollama ollama run gpt-oss:20b"
echo "  - 컨테이너 중지: docker compose down"
echo "  - 컨테이너 중지 및 데이터 삭제: docker compose down -v"
echo ""
