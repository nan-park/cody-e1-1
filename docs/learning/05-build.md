# 5단계 · Dockerfile 작성과 커스텀 이미지 빌드

> 실습 로그: [`docs/logs/05-build.log`](../logs/05-build.log)
> 결과물: [`Dockerfile`](../../Dockerfile), [`app/`](../../app)

## 배운 개념

### 왜 Dockerfile인가

컨테이너에 직접 들어가 설치하고 `docker commit` 하는 방법도 있지만:

- **뭘 했는지 기록이 안 남는다** — 3개월 뒤 "여기 뭘 설치했더라?"에 답할 수 없다
- **재현이 안 된다** — 팀원에게 "터미널 열고 이거 치고 저거 치고…"를 설명해야 한다
- **Git으로 관리할 수 없다** — 이미지는 수백 MB 덩어리라 버전 관리가 안 된다

```
Dockerfile (몇 KB 텍스트)  ──docker build──→  이미지 (수십~수백 MB)
     ↑
  Git 관리 가능, 읽으면 뭘 했는지 알 수 있음, 누가 실행해도 같은 결과
```

> 환경을 **코드로 적는다**고 해서 Infrastructure as Code라 부른다.
> 미션 도입부의 "재현 가능한 환경"이 실제로 구현되는 방식이 이것.

### Dockerfile 주요 명령어

| 명령 | 하는 일 | 비유 |
|---|---|---|
| `FROM` | 베이스 이미지 지정 (필수, 항상 맨 처음) | 어떤 반죽으로 시작할지 |
| `COPY` | 내 컴퓨터의 파일을 이미지 안으로 복사 | 재료 넣기 |
| `RUN` | **빌드할 때** 이미지 안에서 명령 실행 | 조리 과정 |
| `ENV` | 환경변수 설정 | 기본 양념 |
| `EXPOSE` | 사용할 포트를 문서에 남김 | 라벨 표기 |
| `HEALTHCHECK` | 컨테이너가 정상 응답하는지 주기적 확인 | 검수 기준 |
| `LABEL` | 이미지에 메타정보 기록 | 제조사 표시 |
| `CMD` | **시작할 때** 실행할 기본 명령 (= PID 1) | 서빙 방법 |

### 내가 만든 이미지 (미션 요구 A안)

```
베이스: nginx:1.27-alpine  (공식 웹 서버 이미지)
  ① 정적 콘텐츠 교체        : app/site → /usr/share/nginx/html
  ② 환경변수 기반 설정 주입  : app/templates → 시작 시 실제 설정으로 치환
  ③ 헬스체크 추가           : /healthz 를 10초마다 확인
  ④ 이미지 메타데이터        : LABEL 로 출처/용도 기록
```

`alpine`은 초경량 리눅스 배포판(약 8MB). 우분투(78MB)보다 훨씬 작아 이미지 경량화에 널리 쓰인다.

**커스텀 포인트별 목적**

| 포인트 | 목적 |
|---|---|
| 정적 콘텐츠 교체 | 베이스 이미지의 기본 페이지 대신 내 페이지를 서빙 |
| 환경변수 설정 템플릿 | 포트/모드를 **재빌드 없이** 바꾸기 (설정과 코드의 분리) |
| `/healthz` + HEALTHCHECK | "떠 있음"이 아니라 "정상 응답함"을 검증 |
| LABEL | 이미지가 쌓였을 때 출처/용도 추적 |

### 빌드 명령

```sh
docker build -t cody-web:1.0 .
             └─ 이름:태그 ─┘  └ 빌드 컨텍스트(현재 폴더)
```

마지막 `.`은 Dockerfile 위치가 아니라 **데몬에게 통째로 보낼 폴더**.
`COPY app/site/`가 이 폴더 기준으로 해석되며, **컨텍스트 밖의 파일은 `COPY`할 수 없다**(`COPY ../secret.txt` 불가).

`.dockerignore`로 `.git`, `docs` 등을 제외해서 전송량이 4.26kB로 줄었다.

### ⭐ 층(layer)의 정체

`docker history cody-web:1.0` 결과:

```
9316f625dded  14초 전   HEALTHCHECK …                          0B      ┐
<missing>     14초 전   EXPOSE [8080/tcp]                      0B      │
<missing>     14초 전   COPY app/templates/…                   1.2kB   │ 내가
<missing>     14초 전   RUN rm -f /etc/nginx/conf.d/default…   0B      │ 추가한
<missing>     15초 전   COPY app/site/ /usr/share/nginx/html/  2.81kB  │ 7개 층
<missing>     15초 전   ENV APP_ENV=dev NGINX_PORT=8080        0B      │
<missing>     15초 전   LABEL org.opencontainers.image.title…  0B      ┘
<missing>     15개월 전 RUN … apkArch … (nginx 설치)            36.3MB  ┐ nginx
<missing>     15개월 전 CMD ["nginx" "-g" "daemon off;"]       0B      │ 팀이
<missing>     15개월 전 ENTRYPOINT ["/docker-entrypoint.sh"]   0B      ┘ 쌓은 층
<missing>     17개월 전 ADD alpine-minirootfs-3.21.3.tar.gz    7.83MB  ← alpine 바닥
```

> **Dockerfile의 명령 한 줄 = 층 하나.**
> 이미지는 단일 덩어리가 아니라 **투명 필름을 겹겹이 쌓은 것**이다.

관찰 포인트 둘:

1. **`LABEL`, `ENV`, `EXPOSE`는 0B** — 파일을 만들지 않고 정보만 기록하므로 용량을 안 먹는다. `COPY`는 실제 파일이라 크기가 잡힌다.
2. **내가 얹은 건 4KB인데 이미지는 48.2MB** — 대부분이 베이스. **베이스 선택이 최종 크기를 좌우한다.** (우분투 기반이면 190MB쯤)

### ⭐ 캐시 — 층이 있어서 좋은 점

**아무것도 안 바꾸고 재빌드** → 전부 `CACHED`, 1초 만에 완료.

**`index.html`만 1줄 고치고 재빌드**:

```
#6 [2/4] COPY app/site/ …      DONE 0.2s    ← 캐시 깨짐 (당연)
#7 [3/4] RUN rm -f …           DONE 0.4s    ← 안 바꿨는데 다시 실행 (?)
#8 [4/4] COPY app/templates/…  DONE 0.3s    ← 이것도 (?)
```

> **층이 하나 깨지면, 그 위의 모든 층도 다시 만들어진다.**
> 3번째 필름을 갈아 끼우면 그 위 필름들도 다시 얹어야 하니 필연.

**그래서 Dockerfile은 "잘 안 바뀌는 것을 위에, 자주 바뀌는 것을 아래에" 쓴다.**

```dockerfile
COPY package.json .      ← 어쩌다 한 번 바뀜
RUN npm install          ← 무거운 작업(몇 분)   ↑ 위에 둬야 캐시가 산다
COPY . .                 ← 코드는 매번 바뀜     ↓ 아래에
```

순서를 뒤집으면 코드 한 줄 고칠 때마다 `npm install`이 처음부터 다시 돈다.

### FROM은 설정까지 물려받는다

```
$ docker inspect cody-web:1.0
Labels = {"maintainer":"NGINX Docker Maintainers…",   ← nginx가 남긴 것
          "org.opencontainers.image.authors":"nan-park"}  ← 내가 남긴 것
ENV    = [… NGINX_VERSION=1.27.5 … APP_ENV=dev NGINX_PORT=8080]  ← 베이스 + 내 것
CMD    = [nginx -g daemon off;]        ← 쓴 적 없는데 있다 (물려받음)
EXPOSE = map[80/tcp 8080/tcp]          ← 80은 베이스, 8080은 내가
```

`CMD`를 안 썼는데 nginx가 실행되는 이유가 이것.
`daemon off`가 핵심인데, nginx는 원래 백그라운드로 도는 프로그램이라 그냥 두면 **PID 1이 즉시 끝나 컨테이너가 죽는다.** 4단계의 `sleep infinity`와 같은 이유.

### 환경변수 치환이 실제로 일어난 증거

```
$ docker logs web-nomap
20-envsubst-on-templates.sh: Running envsubst on /etc/nginx/templates/default.conf.template
                             to /etc/nginx/conf.d/default.conf

$ docker exec web-nomap wget -qO- http://127.0.0.1:8080/env
APP_ENV=dev
NGINX_PORT=8080
```

이 자동 치환은 **Docker의 기능이 아니라 nginx 이미지가 제공하는 고유 기능**이다.

### 헬스체크 동작 확인

```
web-nomap   Up Less than a second (health: starting)     ← 처음
web-nomap   Up 30 seconds (healthy)                      ← 14초 뒤
```

프로세스가 살아있는 것과 서비스가 정상인 건 다르다. 설정 오류로 모든 요청에 500을 뱉어도 `docker ps`에는 `Up`으로 보인다. 헬스체크는 **실제로 응답하는지**를 본다.

### 컨테이너 안에서는 되는데 밖에서는 안 된다

```
$ docker exec web-nomap wget -qO- http://127.0.0.1:8080/   → 내 페이지 정상 출력 ✅
$ curl --max-time 3 http://localhost:8080/                  → 종료코드 7 (연결 불가) ❌
```

`docker ps`의 PORTS에 `8080/tcp`가 있는데도 안 된다.
**`EXPOSE`는 문서 표기일 뿐 문을 여는 게 아니다.** → 6단계 포트 매핑으로 이어짐.

---

## 처음 접할 때 어려운 개념 (정리)

### 1. 빌드 시점 vs 실행 시점 — 가장 큰 벽

| | 오해 | 실제 |
|---|---|---|
| `RUN` | 실행할 때 도는 명령 | **빌드할 때 한 번** 돌고 결과가 이미지에 굳음 |
| `CMD` | 빌드할 때 도는 명령 | **시작할 때** 돌고 PID 1이 됨 |
| `ENV` | 실행할 때만 유효 | 빌드 중에도, 실행 중에도 유효 |

`RUN npm start`로 서버를 띄우려 하면 **빌드가 끝나지 않고 멈춘다.**

> **기억법**: `RUN`은 붕어빵 **틀 만들 때**, `CMD`는 붕어빵 **구울 때**.

### 2. `EXPOSE`는 포트를 열지 않는다

```
EXPOSE 8080     → "이 이미지는 8080을 씁니다"라는 메모 (문서)
-p 8080:8080    → 실제로 통로를 뚫는 것 (동작)
```

> **기억법**: `EXPOSE`는 **문패**, `-p`는 **문**.

### 3. 이미지는 수정할 수 없다

"이미지를 수정한다"는 표현을 쓰기 쉽지만 이미지는 **읽기 전용**이다. 고치려면 Dockerfile을 바꿔 **새로 빌드**해야 한다.
그래서 컨테이너를 전부 지워도 `docker images`의 이미지는 남는다.

### 4. 안 바꾼 줄이 왜 다시 실행되나 → 레이어 캐시

층이 하나 깨지면 그 위가 전부 깨진다. 이걸 알아야 "자주 바뀌는 건 아래에"라는 작성 원칙이 이해된다.

### 5. 경로가 두 세계에 걸쳐 있다

```dockerfile
COPY app/site/ /usr/share/nginx/html/
     └ 내 맥 ┘  └── 이미지 내부 ──┘
```

> **기억법**: Docker에서 나란히 놓인 두 경로는 거의 항상 **`호스트:컨테이너`** 순서.
> `-p 8080:8080`, `-v ./site:/usr/share/nginx/html` 전부 같은 규칙.

### 6. 내가 안 쓴 설정이 왜 있나 → `FROM` 상속

`FROM`은 파일만이 아니라 **CMD·ENV·ENTRYPOINT·EXPOSE까지 물려받는다.**
새 베이스를 쓸 땐 그 이미지의 Dockerfile을 한 번 읽어보는 습관이 중요하다(Docker Hub에 공개돼 있음).

### 7. Docker 기능 vs 이미지 고유 기능

```
Docker의 기능   : FROM, COPY, ENV, -p, -v …        (어디서나 동일)
이미지 고유 기능 : nginx 템플릿 치환, postgres 초기화 스크립트 …
```

대부분의 "왜 안 되지"는 Docker Hub의 이미지 설명 페이지에 적혀 있다.

### 8. `latest`는 최신이 아니다

그냥 **기본 태그 이름**. 어제의 `latest`와 오늘의 `latest`가 다를 수 있다. 실무에선 버전 고정.

---

## 스스로 점검하는 질문

이 답이 바로 나오면 5단계를 소화한 것.

1. `RUN`과 `CMD`는 각각 언제 실행되나?
2. `EXPOSE 8080`을 썼는데 왜 브라우저에서 접속이 안 되나?
3. `index.html`만 고쳤는데 왜 `RUN` 명령까지 다시 실행되나?
4. `COPY app/site/ /usr/share/nginx/html/`에서 두 경로는 각각 어디인가?
5. `CMD`를 안 썼는데 컨테이너가 nginx를 실행하는 이유는?
6. 컨테이너를 전부 지워도 `docker images`에 이미지가 남는 이유는?
7. `docker build` 마지막의 `.`은 무엇을 의미하나?
8. 이미지 크기를 줄이려면 무엇부터 봐야 하나?

## 5단계 체크

- [x] 기존 베이스(`nginx:1.27-alpine`) 기반 커스텀 이미지 **빌드 성공** (`cody-web:1.0`, 48.2MB)
- [x] 커스텀 포인트 4가지 적용 (콘텐츠 / 환경변수 설정 / 헬스체크 / LABEL)
- [x] 컨테이너 **실행 성공** 및 `healthy` 판정
- [x] 레이어 구조와 캐시 동작을 재빌드 실험으로 확인
