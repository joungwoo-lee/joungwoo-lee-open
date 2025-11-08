# Sandboxdocker Run Guide

이 레포는 `main` 브랜치 변경 시 자동으로
- `sandboxdocker.tar` (Docker 이미지) 와
- `docker-compose.yml`
을 **GitHub Release (tag: build-latest)** 에 올리고,
- **Docker Hub**에도 동시에 배포합니다.

아래 명령만 실행하면 바로 기동됩니다.

---

## Quick Start (원클릭 설치)

가장 간단한 방법 - 스크립트 하나로 끝!

```bash
# 스크립트 다운로드 및 실행
wget https://raw.githubusercontent.com/joungwoo-lee/joungwoo-lee-open/main/run_sandboxdocker.sh
bash run_sandboxdocker.sh
```

스크립트는 두 가지 방식을 선택할 수 있습니다:
1. **Docker Hub 방식** (권장) - 빠르고 간편
2. **GitHub Release tar 방식** - 오프라인 환경 가능

---

## Quick Start (수동 설치)

### 방법 1: Docker Hub (권장)

```bash
# 1) docker-compose.yml 다운로드
wget https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/docker-compose.yml

# 2) 컨테이너 실행 (이미지 자동 pull)
docker compose up -d

# 3) 컨테이너 접속
docker compose exec sandboxdocker bash
```

### 방법 2: GitHub Release tar 파일

```bash
# 1) tar 파일 다운로드
wget https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/sandboxdocker.tar

# 2) 이미지 로드 및 태그
docker load -i sandboxdocker.tar
docker tag sandboxdocker:latest evolve1/sandboxdocker:latest

# 3) docker-compose.yml 다운로드
wget https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/docker-compose.yml

# 4) 컨테이너 실행
docker compose up -d

# 5) 컨테이너 접속
docker compose exec sandboxdocker bash
```



### Windows PowerShell 사용 시:

**방법 1: Docker Hub (권장)**

```powershell
# 1) docker-compose.yml 다운로드
curl.exe -f -L -o "docker-compose.yml" "https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/docker-compose.yml"

# 2) 컨테이너 실행 (이미지 자동 pull)
wsl docker compose up -d

# 3) 컨테이너 접속
wsl docker compose exec sandboxdocker bash
```

**방법 2: GitHub Release tar 파일**

```powershell
# 1) tar 파일 다운로드
curl.exe -f -L -o "sandboxdocker.tar" "https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/sandboxdocker.tar"

# 2) 이미지 로드 및 태그
wsl docker load -i sandboxdocker.tar
wsl docker tag sandboxdocker:latest evolve1/sandboxdocker:latest

# 3) docker-compose.yml 다운로드
curl.exe -f -L -o "docker-compose.yml" "https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/docker-compose.yml"

# 4) 컨테이너 실행
wsl docker compose up -d

# 5) 컨테이너 접속
wsl docker compose exec sandboxdocker bash
```


---

# What this compose does

Ports

37910, 37911, 37912, 37913, 37914, 37915, 38010, 38011 을 동일 번호로 노출


Volume

호스트 ~ 를 컨테이너 /root/ext_volume 에 바인드


Working dir

/root/ext_volume


Entrypoint

이미지 내부 /root/sandboxdocker/autorun.sh 가 있으면 실행 후 대기


Env

INTERNAL_LLM_API_BASE (default: http://host.docker.internal:11434/v1)

INTERNAL_LLM_API_KEY  (default: dev-key)


Restart

restart: always



환경변수 값을 바꾸려면 docker-compose.yml 의 environment 섹션을 수정하세요.


---

## Update to latest

새 빌드가 올라오면 아래만 다시 실행하면 됩니다.

**Docker Hub 사용 시 (권장):**
```bash
docker compose pull
docker compose up -d
```

**GitHub Release 사용 시:**
```bash
wget -O sandboxdocker.tar https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/sandboxdocker.tar
docker load -i sandboxdocker.tar
docker compose up -d
```

---

Stop and remove

docker compose down


---

Troubleshooting

포트 충돌: 이미 해당 포트를 쓰는 프로세스가 있으면 docker compose up -d 가 실패합니다. 사용 중인 프로세스를 종료하거나 docker-compose.yml 의 포트를 다른 값으로 수정하세요.

권한 문제(Windows): PowerShell에서 관리자 권한으로 실행하거나, Git Bash에서 실행하세요.

이미지 손상 의심: sandboxdocker.tar 를 다시 다운로드 후 docker load -i sandboxdocker.tar 를 재실행하세요.
