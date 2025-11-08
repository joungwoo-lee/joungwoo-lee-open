#!/bin/bash
# 1) tar와 compose 파일 받기
wget https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/docker-compose.yml
wget https://github.com/joungwoo-lee/joungwoo-lee-open/releases/download/build-latest/sandboxdocker.tar

# 2) 이미지 로드
docker load -i sandboxdocker.tar

# 2-1) 이미지 태그 변경 (docker-compose.yml과 일치시키기)
docker tag sandboxdocker:latest evolve1/sandboxdocker:latest

# 3) 컨테이너 실행
docker compose up -d

# 4) 컨테이너 접속 (시작 위치: /root/ext_volume)
docker compose exec sandboxdocker bash
