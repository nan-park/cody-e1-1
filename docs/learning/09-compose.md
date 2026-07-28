# 9단계 · Docker Compose (보너스)

> 실습 로그: [`docs/logs/09-compose.log`](../logs/09-compose.log)
> 결과물: [`docker-compose.yml`](../../docker-compose.yml)

## 왜 Compose인가

지금까지 쓴 실행 명령들:

```sh
docker run -d -p 8080:8080 --name web-8080 cody-web:1.0
docker run -d -p 8082:9090 -e NGINX_PORT=9090 -e APP_ENV=production --name web-9090 cody-web:1.0
docker run -d -p 8083:8080 -v "$(pwd)/app/site:/usr/share/nginx/html:ro" --name web-bind cody-web:1.0
```

문제 셋:
- **기억에 의존한다** — 며칠 뒤 "그때 옵션이 뭐였지?"
- **공유가 안 된다** — 팀원에게 긴 명령을 채팅으로 보내야 함
- **서비스가 여러 개면 손이 못 따라간다** — 웹+DB+캐시면 명령 3개에 순서까지 신경 써야 함

```
docker run -d -p ... -e ... -v ...     →     docker-compose.yml  (Git으로 관리)
   (휘발성 명령, 사람 기억에 의존)              docker compose up  (한 줄로 실행)
```

> **Compose는 새로운 기술이라기보다 기록 방식이다.**
> 지금까지 배운 `run` 옵션을 파일로 옮겨 적은 것뿐이고, 새로 등장한 개념이 거의 없다.

## `docker run` 옵션 ↔ Compose 키 대응

| `docker run` | `docker-compose.yml` |
|---|---|
| `-p 8090:8080` | `ports:` |
| `-e KEY=VALUE` | `environment:` |
| `-v 경로:경로` | `volumes:` |
| `--name` | `container_name:` |
| `--restart` | `restart:` |
| `-t 이름:태그` (build) | `image:` + `build:` |
| (없음) | `depends_on:` — 시작 순서 |

## 작성한 구성

```yaml
services:
  web:
    build: .                                  # 5단계의 Dockerfile 을 그대로 사용
    image: cody-web:1.0
    ports: ["8090:8080"]
    environment:
      APP_ENV: compose
      NGINX_PORT: 8080
    volumes:
      - ./app/site:/usr/share/nginx/html:ro   # 바인드 마운트
    depends_on: [cache]
    restart: unless-stopped

  cache:
    image: redis:7-alpine
    volumes:
      - cache-data:/data                      # 이름 있는 볼륨
    restart: unless-stopped
    # ports 를 쓰지 않음 → 호스트에 노출되지 않고 web 에서만 접근 가능

volumes:
  cache-data:
```

### 7단계의 두 가지가 한 파일에

```yaml
- ./app/site:/usr/share/nginx/html:ro    # . 으로 시작 → 바인드 마운트
- cache-data:/data                       # 그냥 이름 → 볼륨
```

> **Compose에서는 예외적으로 상대경로(`./`)를 써도 된다.**
> `docker run`과 달리 Compose는 YAML 파일 위치를 기준점으로 알고 있어 절대경로로 바꿔 해석해 준다.
> 덕분에 `$(pwd)` 없이도 팀원 누구나 같은 파일로 실행할 수 있다.

## 실행 — 네트워크·볼륨까지 자동 생성

```
$ docker compose up -d
 Network cody-e1-1_default  Created      ← 전용 네트워크 자동 생성
 Volume cody-e1-1_cache-data  Created    ← 볼륨도 자동 생성
 Container cody-cache  Started           ← depends_on 순서대로 cache 먼저
 Container cody-web  Started
```

이름 앞의 `cody-e1-1_`은 **프로젝트 이름**(기본값 = 폴더 이름)으로, 다른 프로젝트와 섞이지 않게 붙는 접두어.

```
$ curl -s http://localhost:8090/env
APP_ENV=compose            ← YAML에 적은 값이 주입됨
NGINX_PORT=8080
```

## ⭐ 서비스 디스커버리 — 컨테이너 간 통신

```
$ docker compose exec web getent hosts cache
192.168.97.2      cache                      ← "cache"라는 이름이 IP로 해석된다

$ docker compose exec web sh -c 'echo "PING" | nc cache 6379'
+PONG                                        ← 웹 → 캐시 통신 성공

$ docker compose exec cache redis-cli set greeting "hello-from-compose"
OK
```

**서비스 이름이 곧 주소다.** Compose가 만든 전용 네트워크에는 자체 DNS가 있어 이름으로 연결된다.

> **왜 중요한가**: 컨테이너 IP는 재시작할 때마다 바뀐다.
> IP를 코드에 적어두면 다시 띄울 때마다 깨지지만, 이름으로 부르면 그럴 일이 없다.

실제 애플리케이션 설정 예:

```
DATABASE_URL=postgres://db:5432/mydb     ← IP가 아니라 서비스 이름 "db"
REDIS_URL=redis://cache:6379             ← 서비스 이름 "cache"
```

## 열지 않은 포트는 밖에서 못 들어온다

```
$ curl -s --max-time 3 http://localhost:6379
종료코드=7                    ← 호스트에서는 접근 불가
```

```
    바깥 세상
       │  8090만 열림
   ┌───▼──────────────────────────────┐
   │  Compose 전용 네트워크             │
   │   ┌─────────┐      ┌──────────┐  │
   │   │  web    │─────▶│  cache   │  │  ← 내부끼리는 자유롭게
   │   │ (8080)  │      │ (6379)   │  │
   │   └─────────┘      └──────────┘  │
   └──────────────────────────────────┘
```

> **보안의 기본 원칙.** DB·캐시는 웹 서버만 접근하면 되므로 외부에 노출할 이유가 없다.
> 실무에서 DB 포트를 습관적으로 여는 게 흔한 실수인데, Compose를 쓰면 자연스럽게 안 열게 된다.

## 운영 명령 4종

| 명령 | 하는 일 |
|---|---|
| `docker compose up -d` | 빌드·생성·시작 (없는 것만) |
| `docker compose ps` | 이 프로젝트의 컨테이너 상태 |
| `docker compose logs` | 전체 서비스 로그를 **이름표 붙여 합쳐서** 보기 |
| `docker compose down` | 중지 + 컨테이너·네트워크 삭제 |

```
$ docker compose logs --tail 5
cody-web    | 192.168.97.1 - - [...] "GET /env HTTP/1.1" 200 32 "-" "curl/8.7.1"
cody-cache  | 1:M 28 Jul 2026 09:28:46.584 * Ready to accept connections tcp
```

서비스가 늘어날수록 이 합쳐보기의 가치가 커진다.
"웹이 요청을 받았나 → 캐시가 응답했나"를 시간순으로 한 번에 볼 수 있다.

## `down` 해도 데이터는 남는다

```
$ docker compose down
 Container cody-web  Removed
 Container cody-cache  Removed
 Network cody-e1-1_default  Removed      ← 컨테이너와 네트워크는 삭제

$ docker volume ls
local     cody-e1-1_cache-data            ← 볼륨은 그대로 ✅

$ docker compose up -d
$ docker compose exec cache redis-cli get greeting
hello-from-compose                        ← 껐다 켰는데 데이터가 살아있다 ✅
```

7단계에서 증명한 볼륨의 영속성이 Compose에서도 그대로 적용된다. `down`은 **의도적으로 볼륨을 건드리지 않는다.**

> ⚠️ 데이터까지 지우려면 `docker compose down -v`.
> **`-v`를 붙이는 순간 DB 데이터가 전부 날아간다.** 실무 사고가 잦은 옵션이므로 치기 전에 한 번 더 생각할 것.

## 헷갈리기 쉬운 지점

### 1. `docker-compose` vs `docker compose`

과거에는 별도 파이썬 프로그램(`docker-compose`, 하이픈)이었고, 지금은 Docker CLI에 내장된 플러그인(`docker compose`, 공백)이다.
이 실습은 v2(`docker compose`) 기준이며 `docker compose version`으로 확인했다.

### 2. `depends_on`은 "준비 완료"를 기다리지 않는다

**시작 순서만** 보장한다. cache 컨테이너가 시작됐다고 redis가 접속을 받을 준비가 된 것은 아니다.
확실히 하려면 `depends_on`에 `condition: service_healthy`와 헬스체크를 함께 써야 한다.

### 3. `up`은 변경분만 다시 만든다

이미 떠 있는 서비스는 건드리지 않고, YAML이 바뀐 서비스만 다시 생성한다.
강제로 다시 만들려면 `--force-recreate`, 이미지를 다시 빌드하려면 `--build`.

## 스스로 점검하는 질문

1. `docker run -p 8090:8080 -e A=B` 는 Compose에서 어떤 키가 되나?
2. 웹 컨테이너에서 캐시 서버를 부를 때 IP 대신 무엇을 쓰나? 왜?
3. `cache` 서비스에 `ports:`를 쓰지 않은 이유는?
4. `docker compose down` 과 `down -v` 의 차이는?
5. Compose에서만 상대경로 마운트가 허용되는 이유는?

## 보너스 체크

- [x] **Compose 기초** — 실행 설정을 파일로 문서화
- [x] **멀티 컨테이너** — web + cache 2개 서비스, 컨테이너 간 통신 확인 (`+PONG`)
- [x] **운영 명령** — `up` / `ps` / `logs` / `down`
- [x] **환경 변수 활용** — `APP_ENV=compose` 주입 확인
