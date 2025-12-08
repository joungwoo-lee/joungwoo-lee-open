# Ollama GPU 가속 테스트 환경

이 폴더는 Ollama를 Docker Compose로 실행하고 GPU 가속을 적용한 후, gpt-oss:20b 모델을 테스트하는 환경입니다.

## 구성 요소

- `docker-compose.yml`: Ollama 컨테이너를 GPU 가속과 함께 실행하는 설정
- `.env`: test 파일(test_langchain_openai.py, test_openai.py)용 API 설정 및 환경 변수
- `setup_and_test.sh`: 전체 설정 및 테스트를 자동으로 실행하는 스크립트
- `llm_connector_openai.py`: OpenAI 라이브러리를 사용한 테스트 코드
- `llm_connector_langchain_openai.py`: LangChain OpenAI를 사용한 테스트 코드

## 사용 방법

### 자동 실행 (권장)

```bash
cd ollama_setup
./setup_and_test.sh
```

이 스크립트는 다음을 자동으로 수행합니다:
1. NVIDIA Container Toolkit 설치 확인 및 설치
2. GPU 접근 테스트
3. Docker Compose로 Ollama 컨테이너 실행
4. gpt-oss:20b 모델 다운로드
5. Python 테스트 코드 2개 순차 실행

### 수동 실행

1. **환경 변수 설정**
   `.env` 파일을 확인하고 필요시 수정하세요.

2. **NVIDIA Container Toolkit 설치** (GPU 사용시)
   ```bash
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
     sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

   curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

   sudo apt-get update
   sudo apt-get install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo service docker restart
   ```

3. **GPU 테스트**
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
   ```

4. **Docker Compose 실행**
   ```bash
   docker compose up -d
   ```

5. **모델 다운로드**
   ```bash
   docker exec ollama ollama pull gpt-oss:20b
   ```

6. **Python 패키지 설치**
   ```bash
   pip3 install python-dotenv openai langchain-openai
   ```

7. **테스트 실행**
   ```bash
   python3 llm_connector_openai.py
   python3 llm_connector_langchain_openai.py
   ```

## 유용한 명령어

- **컨테이너 상태 확인**
  ```bash
  docker compose ps
  ```

- **컨테이너 로그 확인**
  ```bash
  docker compose logs -f
  ```

- **Ollama 직접 실행**
  ```bash
  docker exec -it ollama ollama run gpt-oss:20b
  ```

- **컨테이너 중지**
  ```bash
  docker compose down
  ```

- **컨테이너 중지 및 데이터 삭제**
  ```bash
  docker compose down -v
  ```

## 주의사항

- GPU 가속을 위해서는 NVIDIA GPU와 드라이버가 필요합니다.
- gpt-oss:20b 모델은 크기가 크므로 다운로드에 시간이 걸릴 수 있습니다.
- `.env` 파일의 API_BASE 주소는 사용 환경에 맞게 수정이 필요할 수 있습니다.


# 참고

안되면 이 3가지만 다시 붙여 주세요

Windows PowerShell에서: nvidia-smi 출력

WSL 우분투에서: nvidia-smi 출력

WSL 우분투에서: docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu24.04 nvidia-smi 출력

해당 세 줄만 보면 바로 어디에서 끊겼는지 짚어서 추가 조치 드리겠습니다.



**컨테이너가 GPU를 못 잡으면** 올라마가 CPU로만 돌고 크게 느려집니다. 아래 스크립트는 **WSL2/리눅스 + NVIDIA 기준**으로,

1. 점검 → 2) 자동 복구(필요 시) → 3) 재검증까지 한 번에 수행합니다.

> 사용법
>
> ```bash
> bash ollama_gpu_doctor.sh             # 표준 점검/복구
> bash ollama_gpu_doctor.sh --no-fa     # Flash Attention 끄고 재구성(문제시)
> bash ollama_gpu_doctor.sh --recreate  # Ollama 컨테이너 강제 재생성
> ```

```bash
#!/usr/bin/env bash
# ollama_gpu_doctor.sh
set -euo pipefail

NO_FA="false"
FORCE_RECREATE="false"
OLLAMA_NAME="${OLLAMA_NAME:-ollama}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_VOL="${OLLAMA_VOL:-ollama}"
CUDA_TEST_IMAGES=("nvidia/cuda:12.6.1-base-ubuntu24.04" "nvidia/cuda:12.4.1-base-ubuntu22.04")

for arg in "$@"; do
  case "$arg" in
    --no-fa) NO_FA="true" ;;
    --recreate) FORCE_RECREATE="true" ;;
    *) echo "알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

say() { echo -e "\n[INFO] $*"; }
warn() { echo -e "\n[WARN] $*" >&2; }
die() { echo -e "\n[FAIL] $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "'$1' 명령어가 필요합니다."; }

need_cmd docker

# 0) 환경 감지 (WSL2 여부)
if grep -qi microsoft /proc/version 2>/dev/null; then
  say "WSL 환경 감지: /proc/version에 Microsoft 문자열 발견"
else
  say "네이티브 Linux 환경으로 판단"
fi

# 1) WSL/Linux에서 GPU 드라이버 노출 점검
if command -v nvidia-smi >/dev/null 2>&1; then
  say "호스트(WSL/Linux)에서 GPU 확인 (nvidia-smi)"
  nvidia-smi || warn "nvidia-smi 실행 실패(드라이버 이상 가능). 계속 진행은 가능하나 결과가 불안정할 수 있습니다."
else
  warn "호스트에 'nvidia-smi'가 없습니다. WSL 통합/드라이버 미설치 가능성이 큽니다."
  warn "- Windows: NVIDIA 드라이버 최신 설치"
  warn "- Docker Desktop: Resources > GPU 'Enable GPU acceleration' 체크, WSL Integration 활성화"
fi

# 2) 도커 런타임에 NVIDIA 지원 있는지 확인
say "docker info 런타임 확인"
if docker info 2>/dev/null | grep -qiE '^ Runtimes: .*nvidia'; then
  say "도커 런타임에 nvidia 엔트리 존재"
else
  warn "도커 런타임에 nvidia가 없습니다. NVIDIA Container Toolkit 구성 시도(nvidia-ctk)..."
  if command -v nvidia-ctk >/dev/null 2>&1; then
    sudo nvidia-ctk runtime configure --runtime=docker || warn "nvidia-ctk runtime configure 실패"
    # 데몬 재시작
    if command -v systemctl >/dev/null 2>&1; then
      sudo systemctl restart docker || sudo service docker restart || true
    else
      sudo service docker restart || true
    fi
  else
    warn "nvidia-ctk가 없습니다. (WSL Ubuntu에서 'sudo apt-get install -y nvidia-container-toolkit' 필요)"
  fi
fi

# 3) 컨테이너에서 GPU가 보이는지 사전검증 (테스트 이미지로)
TEST_OK="false"
say "컨테이너에서 GPU 인식 테스트(nvidia/cuda:* 이미지)"
for img in "${CUDA_TEST_IMAGES[@]}"; do
  say "시도: docker run --rm --gpus all $img nvidia-smi"
  if docker run --rm --gpus all "$img" nvidia-smi; then
    TEST_OK="true"
    say "→ 컨테이너 내부에서 GPU 확인 성공 ($img)"
    break
  else
    warn "→ 실패 ($img). Docker Hub 레이트리밋/네트워크/태그 불일치 가능"
  fi
done
if [[ "$TEST_OK" != "true" ]]; then
  warn "테스트 이미지를 못 받았거나 실행 실패했습니다. (로그인/네트워크/레이트리밋 확인 필요)"
  warn "그래도 Ollama 컨테이너 기준으로 계속 점검/복구를 진행합니다."
fi

# 4) Ollama 컨테이너 상태 점검
if docker ps --format '{{.Names}}' | grep -qx "$OLLAMA_NAME"; then
  say "기존 Ollama 컨테이너가 실행 중입니다: $OLLAMA_NAME"
else
  warn "Ollama 컨테이너가 실행 중이 아닙니다."
  FORCE_RECREATE="true"
fi

# 5) 컨테이너 내부에 GPU 디바이스 노출 확인 (/dev/nvidia* or /dev/dxg)
check_gpu_devs() {
  docker exec -it "$OLLAMA_NAME" bash -lc 'ls -l /dev/nvidia* 2>/dev/null || true; ls -l /dev/dxg 2>/dev/null || true' || true
}

if [[ "$FORCE_RECREATE" == "false" ]]; then
  say "현재 컨테이너의 디바이스 노출 상태 확인"
  check_gpu_devs
fi

# 6) 필요 시 컨테이너 재생성(+옵션 튜닝)
if [[ "$FORCE_RECREATE" == "true" ]]; then
  say "Ollama 컨테이너를 GPU 옵션으로 재생성합니다."
  docker stop "$OLLAMA_NAME" >/dev/null 2>&1 || true
  docker rm "$OLLAMA_NAME"   >/dev/null 2>&1 || true

  # Flash Attention 토글
  FA_ENV=""
  if [[ "$NO_FA" == "true" ]]; then
    FA_ENV="-e OLLAMA_FLASH_ATTENTION=false"
    say "Flash Attention 비활성화 모드로 실행"
  fi

  set -x
  docker run -d --name "$OLLAMA_NAME" --restart unless-stopped -p "${OLLAMA_PORT}:11434" --gpus all \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e OLLAMA_KEEP_ALIVE=30s \
    $FA_ENV \
    -v "${OLLAMA_VOL}:/root/.ollama" \
    ollama/ollama:latest
  { set +x; } 2>/dev/null

  say "재생성된 컨테이너의 디바이스 노출 확인"
  check_gpu_devs
fi

# 7) 올라마 로그에서 CUDA 백엔드/오프로딩 확인
say "Ollama 로그에서 GPU 사용 여부 검사"
GPU_OK="false"
LOG=$(docker logs --tail=400 "$OLLAMA_NAME" 2>&1 || true)

echo "$LOG" | grep -E 'loaded CUDA backend|offloaded [0-9]+/[0-9]+ layers to GPU|device=CUDA[0-9]' && GPU_OK="true" || true
echo "$LOG" | grep -E 'failed to initialize CUDA:|no compatible GPUs were discovered' >/dev/null && FAIL_MARK="true" || FAIL_MARK="false"

if [[ "$GPU_OK" == "true" && "$FAIL_MARK" == "false" ]]; then
  say "결론: ✅ GPU 가속 정상 동작 감지"
else
  warn "결론: ⚠️ GPU 사용이 불안정하거나 실패 흔적이 있습니다."
  warn "아래 키워드를 기준으로 원인 파악:"
  echo "$LOG" | grep -E 'failed to initialize CUDA:|no compatible GPUs were discovered|VRAM usage didn.t recover|old CUDA driver detected' || true
fi

# 8) 추가 권고(표시만)
say "추가 권고:"
echo "- Windows NVIDIA 드라이버를 최신으로 유지(간헐적 'driver version insufficient' 방지)"
echo "- 16GB VRAM이면 8B 모델 + 4bit(Q4_K_M) 권장, num_ctx=4096 유지(과다 증가 금지)"
echo "- 문제가 계속되면: 'wsl --shutdown' 후 Docker Desktop 완전 재실행 → 스크립트 재실행"
```

---

### 스크립트가 하는 일 (요약)

* **도커 런타임에 NVIDIA 훅**이 있는지 확인하고, 없으면 `nvidia-ctk runtime configure`로 보정 시도
* **컨테이너에서 GPU 보이는지** 테스트(CUDA 공식 이미지)
* **Ollama 컨테이너를 GPU 모드**로 재생성(옵션: Flash Attention 끄기)
* **Ollama 로그를 파싱**해 `loaded CUDA backend`, `device=CUDA0`, `offloaded N/XX layers to GPU` 존재 여부 확인
* 실패 흔적(`failed to initialize CUDA`, `no compatible GPUs`)이 있으면 **경고 및 다음 액션 힌트** 제공

필요하시면 VRAM 16GB 기준 **가장 빠르게 도는 모델/양자화/옵션 세트**도 바로 드리겠습니다.
