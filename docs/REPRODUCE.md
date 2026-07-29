# 재현 절차 (평가자용)

이 저장소의 결과물을 처음부터 직접 확인하는 절차입니다.
README의 각 절에 있는 결과와 동일한 출력이 나오는지 대조할 수 있습니다.

## 사전 조건

- OrbStack(또는 Docker Desktop)이 실행 중일 것
- `docker info | head -20` 실행 시 `Server:` 섹션이 응답하면 정상

```sh
git clone https://github.com/nan-park/cody-e1-1.git
cd cody-e1-1
```

## 1) 커스텀 이미지 빌드

```sh
docker build -t cody-web:1.0 .
docker images | grep cody-web          # 48.2MB 내외
docker history cody-web:1.0            # 레이어 구조 확인
```

## 2) 포트 매핑 (호스트 포트만 다르게, 동일 이미지 2개)

```sh
docker run -d -p 8080:8080 --name web-8080 cody-web:1.0
docker run -d -p 8081:8080 --name web-8081 cody-web:1.0

docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
curl http://localhost:8080/healthz     # ok
curl http://localhost:8081/healthz     # ok
```

브라우저에서 `http://localhost:8080`, `http://localhost:8081` 접속 → 동일 페이지가 표시됩니다.

## 3) 환경 변수 주입 (보너스)

```sh
docker run -d -p 8082:9090 -e NGINX_PORT=9090 -e APP_ENV=production --name web-9090 cody-web:1.0

curl http://localhost:8082/env         # APP_ENV=production / NGINX_PORT=9090
docker exec web-9090 grep listen /etc/nginx/conf.d/default.conf   # listen 9090;
```

이미지를 다시 빌드하지 않고 실행 옵션만으로 포트·모드가 바뀝니다.

## 4) 바인드 마운트 (호스트 변경 즉시 반영)

```sh
docker run -d -p 8083:8080 -v "$(pwd)/app/site:/usr/share/nginx/html:ro" --name web-bind cody-web:1.0

curl -s http://localhost:8083/ | grep "<h1>"
#   app/site/index.html 의 <h1> 문구를 수정한 뒤 위 명령을 다시 실행 → 즉시 반영
curl -s http://localhost:8080/ | grep "<h1>"
#   이미지에 COPY 된 8080 쪽은 그대로 (재빌드 전까지 변하지 않음)

docker exec web-bind sh -c "echo test >> /usr/share/nginx/html/index.html"
#   Read-only file system  ← :ro 로 컨테이너의 호스트 파일 수정 차단
```

## 5) 볼륨 영속성 (컨테이너 삭제 전/후)

```sh
docker volume create cody-data
docker run -d --name vol-test1 -v cody-data:/data ubuntu:24.04 sleep infinity
docker exec vol-test1 sh -c 'echo "중요한 사용자 데이터" > /data/important.txt; date >> /data/important.txt'
docker exec vol-test1 cat /data/important.txt          # [삭제 전] 내용 확인

docker rm -f vol-test1                                 # 컨테이너 강제 삭제
docker volume ls                                       # 볼륨은 남아 있음

docker run -d --name vol-test2 -v cody-data:/data ubuntu:24.04 sleep infinity
docker exec vol-test2 cat /data/important.txt          # [삭제 후] 날짜까지 그대로 유지

docker run --rm -v cody-data:/data alpine cat /data/important.txt   # 다른 이미지에서도 접근 가능
```

### 대조군: 볼륨이 없으면

```sh
docker run -d --name novol ubuntu:24.04 sleep infinity
docker exec novol sh -c 'echo "중요한 사용자 데이터" > /data/important.txt'
docker rm -f novol && docker run -d --name novol ubuntu:24.04 sleep infinity
docker exec novol cat /data/important.txt              # No such file or directory ← 소실
docker rm -f novol
```

## 6) Docker Compose (보너스)

```sh
docker compose up -d
docker compose ps
docker compose logs

docker compose exec web getent hosts cache                    # 서비스 이름 → IP 해석
docker compose exec web sh -c 'echo "PING" | nc cache 6379'   # +PONG
curl -s --max-time 3 http://localhost:6379                    # 종료코드 7 (외부 미노출)
curl -s http://localhost:8090/env                             # APP_ENV=compose

docker compose exec cache redis-cli set greeting hello-from-compose
docker compose down && docker compose up -d
docker compose exec cache redis-cli get greeting              # 값 유지 (이름 있는 볼륨)
docker compose down
```

## 7) 정리

```sh
docker rm -f web-8080 web-8081 web-9090 web-bind vol-test2
docker volume rm cody-data
docker image prune -f
```

---

## 환경 의존적인 부분 (주의사항)

| 항목 | 이 저장소 기준 | 다른 환경에서 |
|---|---|---|
| 컨테이너 런타임 | OrbStack | Docker Desktop / 리눅스 native 모두 동일하게 동작 |
| 바인드 마운트 경로 | `$(pwd)/app/site` | **절대경로 필요.** 상대경로를 쓰면 볼륨 이름으로 해석됨 |
| 호스트 포트 | 8080~8083, 8090 | 사용 중이면 `-p <다른포트>:8080`으로 변경 |
| CPU 아키텍처 | `x86_64` | arm64 환경에서도 동작(멀티아키 베이스). 필요 시 `--platform` 지정 |
| 볼륨 `Mountpoint` | `/var/lib/docker/volumes/...` | macOS에서는 호스트가 아닌 **리눅스 VM 내부** 경로 (README 트러블슈팅 ② 참고) |
