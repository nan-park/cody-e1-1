# 개발 워크스테이션 구축 (Codyssey Mission 1)

터미널 · Docker · Git/GitHub를 사용해 **"내 컴퓨터에서만 돌아가는 문제"를 없애는** 개발 환경을 구성하고,
그 과정을 실행 로그와 증거로 남긴 저장소입니다.

> **모든 실습은 CLI로 수행했으며, 명령어와 출력이 함께 담긴 원본 로그를 [`docs/logs/`](docs/logs)에 보관합니다.**
> 단계별 개념 정리와 시행착오는 [`docs/learning/`](docs/learning)에 학습 일지로 정리했습니다.

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|---|---|
| 목표 | 재현 가능한 실행 환경 구성 및 검증 (터미널 → Docker → Git) |
| 결과물 | `nginx:1.27-alpine` 기반 **커스텀 웹 서버 이미지** (`cody-web:1.0`) |
| 핵심 검증 | 포트 매핑 접속 / 바인드 마운트 실시간 반영 / 볼륨 데이터 영속성 |
| 특이사항 | 서울캠퍼스 sudo 제한 환경 → **OrbStack**으로 Docker 엔진 구동 |

### 이 미션에서 확인한 구조적 원칙

- **이미지와 컨테이너의 분리** — 이미지는 읽기 전용 틀, 컨테이너는 그 위 얇은 쓰기 층. 컨테이너는 언제든 버릴 수 있어야 한다.
- **격리된 실행 환경** — 커널의 네임스페이스/cgroup으로 프로세스·네트워크·파일 시스템이 분리된다.
- **포트·스토리지 연결** — 격리된 컨테이너를 바깥과 잇는 통로가 각각 포트 매핑(`-p`)과 마운트/볼륨(`-v`)이다.

---

## 2. 실행 환경

```
$ sw_vers
ProductName:     macOS
ProductVersion:  15.7.4
BuildVersion:    24G517

$ echo $SHELL
/bin/zsh

$ uname -m
x86_64

$ docker --version
Docker version 28.5.2, build ecc6942

$ docker compose version
Docker Compose version v2.40.3

$ git --version
git version 2.53.0
```

| 항목 | 값 |
|---|---|
| OS | macOS 15.7.4 (Darwin 24.6.0, x86_64) |
| 셸 / 터미널 | zsh |
| 컨테이너 런타임 | Docker 28.5.2 — **OrbStack** 컨텍스트 (sudo 불필요) |
| Docker Compose | v2.40.3 |
| Git | 2.53.0 |

> **OrbStack 사용 이유**: 기본 Docker는 `/var/run/docker.sock`(시스템 영역)을 사용해 설치·제어에 관리자 권한이 필요합니다.
> OrbStack은 소켓을 홈 디렉토리(`~/.orbstack/run/docker.sock`)에 두어 sudo 없이 동작합니다.
> 검증: `docker context ls` 출력이 [`03-docker-check.log`](docs/logs/03-docker-check.log)에 있습니다.

---

## 3. 수행 항목 체크리스트

| # | 항목 | 상태 | 증거 |
|---|---|---|---|
| 1 | 터미널 기본 조작 (위치·목록·이동·생성·복사·이름변경·삭제·내용확인·빈 파일) | ✅ | [01-terminal.log](docs/logs/01-terminal.log) |
| 2 | 절대경로 / 상대경로 비교 실습 | ✅ | [01-terminal.log](docs/logs/01-terminal.log) |
| 3 | 파일 권한 변경 실험 (변경 전/후 비교) | ✅ | [02-permission.log](docs/logs/02-permission.log) |
| 4 | 디렉토리 권한 변경 실험 (변경 전/후 비교) | ✅ | [02-permission.log](docs/logs/02-permission.log) |
| 5 | Docker 설치 확인 (`docker --version`) | ✅ | [03-docker-check.log](docs/logs/03-docker-check.log) |
| 6 | Docker 데몬 동작 확인 (`docker info`) | ✅ | [03-docker-check.log](docs/logs/03-docker-check.log) |
| 7 | `hello-world` 실행 | ✅ | [04-container-run.log](docs/logs/04-container-run.log) |
| 8 | `ubuntu` 컨테이너 내부 진입 후 명령 수행 | ✅ | [04-container-run.log](docs/logs/04-container-run.log) |
| 9 | attach / exec 차이 관찰 및 정리 | ✅ | [04-container-run.log](docs/logs/04-container-run.log) · [학습 일지](docs/learning/04-container-run.md) |
| 10 | 이미지 목록 / 컨테이너 목록 / 로그 / 리소스 확인 | ✅ | [04-container-run.log](docs/logs/04-container-run.log) |
| 11 | **Dockerfile 직접 작성 → 커스텀 이미지 빌드** | ✅ | [Dockerfile](Dockerfile) · [05-build.log](docs/logs/05-build.log) |
| 12 | 커스텀 이미지로 컨테이너 실행 | ✅ | [05-build.log](docs/logs/05-build.log) |
| 13 | **포트 매핑 접속 (2회, 서로 다른 호스트 포트)** | ✅ | [06-port.log](docs/logs/06-port.log) · [스크린샷](#62-브라우저-접속-증거) |
| 14 | **바인드 마운트 실시간 반영 (변경 전/후 비교)** | ✅ | [07-mount-volume.log](docs/logs/07-mount-volume.log) |
| 15 | **볼륨 영속성 (컨테이너 삭제 전/후 비교)** | ✅ | [07-mount-volume.log](docs/logs/07-mount-volume.log) |
| 16 | Git 사용자 정보 / 기본 브랜치 설정 | ✅ | [08-git.log](docs/logs/08-git.log) |
| 17 | GitHub 원격 저장소 연동 및 push | ✅ | [08-git.log](docs/logs/08-git.log) · [스크린샷](#73-연동-증거-스크린샷) |
| 18 | 환경 변수로 설정 주입 (보너스) | ✅ | [06-port.log](docs/logs/06-port.log) |

---

## 4. 저장소 구조

```
cody-e1-1/
├── Dockerfile                  # 커스텀 이미지 레시피 (직접 작성)
├── docker-compose.yml          # 멀티 컨테이너 실행 설정 (보너스)
├── .dockerignore               # 빌드 컨텍스트 제외 목록
├── app/
│   ├── site/                   # 웹 서버가 서빙하는 정적 콘텐츠
│   │   ├── index.html
│   │   └── style.css
│   └── templates/
│       └── default.conf.template   # 환경변수 치환용 nginx 설정 템플릿
└── docs/
    ├── logs/                   # 실행 명령 + 출력 원본 (증거)
    │   ├── 01-terminal.log
    │   ├── 02-permission.log
    │   ├── 03-docker-check.log
    │   ├── 04-container-run.log
    │   ├── 05-build.log
    │   ├── 06-port.log
    │   ├── 07-mount-volume.log
    │   ├── 08-git.log
    │   ├── 09-compose.log
    │   └── 10-ssh.log
    ├── learning/               # 단계별 개념 정리 및 시행착오 (학습 일지)
    └── images/                 # 브라우저 접속 · 연동 스크린샷
```

---

## 5. 커스텀 이미지 설명

### 5.1 선택한 베이스

**`nginx:1.27-alpine`** (공식 이미지) — 미션 요구 (A) 웹 서버 베이스 + 콘텐츠/설정 교체 방식.
`alpine` 계열을 골라 최종 이미지가 **48.2MB**로 유지됩니다. (`ubuntu` 기반이면 약 190MB)

버전을 `latest`가 아닌 `1.27-alpine`으로 고정한 이유는, `latest`는 "최신"이 아니라 **기본 태그 이름**일 뿐이라
시점에 따라 다른 버전이 받아져 재현성이 깨지기 때문입니다.

### 5.2 커스텀 포인트와 목적

| # | 커스텀 포인트 | 목적 |
|---|---|---|
| ① | `COPY app/site/ → /usr/share/nginx/html/` | 베이스 이미지의 기본 페이지를 **내 정적 콘텐츠로 교체** |
| ② | `COPY app/templates/*.template` + `ENV` | 시작 시 `${NGINX_PORT}`/`${APP_ENV}` 치환 → **재빌드 없이 포트·모드 변경** (설정과 코드의 분리) |
| ③ | `HEALTHCHECK` + `/healthz` | "프로세스가 떠 있음"이 아니라 **"실제로 응답함"** 을 검증 |
| ④ | `LABEL org.opencontainers.image.*` | 이미지가 쌓였을 때 **출처·용도를 이미지 자체에서** 확인 |

`RUN rm -f /etc/nginx/conf.d/default.conf`로 80포트를 쓰는 기본 설정을 제거하고 템플릿으로 대체했습니다.
`CMD`는 베이스 이미지의 `nginx -g 'daemon off;'`를 그대로 물려받습니다
(`daemon off`가 없으면 PID 1이 즉시 종료되어 컨테이너가 죽습니다).

### 5.3 빌드 / 실행

```sh
# 빌드
docker build -t cody-web:1.0 .

# 실행 (포트 매핑)
docker run -d -p 8080:8080 --name web-8080 cody-web:1.0
```

빌드 결과 (전체는 [`05-build.log`](docs/logs/05-build.log)):

```
#6 [2/4] COPY app/site/ /usr/share/nginx/html/                        DONE
#7 [3/4] RUN rm -f /etc/nginx/conf.d/default.conf                     DONE
#8 [4/4] COPY app/templates/default.conf.template /etc/nginx/...      DONE
#9 exporting to image ... naming to docker.io/library/cody-web:1.0    DONE

$ docker images
REPOSITORY   TAG   IMAGE ID       CREATED          SIZE
cody-web     1.0   9316f625dded   14 seconds ago   48.2MB
```

헬스체크 동작 확인:

```
$ docker ps
NAMES       STATUS
web-8080    Up Less than a second (health: starting)
web-8080    Up 30 seconds (healthy)              ← 14초 뒤
```

---

## 6. 검증 방법과 결과

### 6.1 포트 매핑 (동일 이미지, 서로 다른 호스트 포트)

```sh
docker run -d -p 8080:8080 --name web-8080 cody-web:1.0
docker run -d -p 8081:8080 --name web-8081 cody-web:1.0
```

```
$ docker ps --format "table {{.Names}}\t{{.Ports}}"
NAMES      PORTS
web-8081   0.0.0.0:8081->8080/tcp      ← 호스트 8081 → 컨테이너 8080
web-8080   0.0.0.0:8080->8080/tcp      ← 호스트 8080 → 컨테이너 8080

$ curl -s http://localhost:8080/healthz && curl -s http://localhost:8081/healthz
ok
ok

$ curl -s -i http://localhost:8080/ | head -4
HTTP/1.1 200 OK
Server: nginx/1.27.5
Content-Type: text/html
Content-Length: 1159
```

**두 컨테이너 모두 내부에서는 8080을 쓰지만, 호스트 포트가 다르면 동시에 실행됩니다.**
컨테이너별로 네트워크가 격리되어 있기 때문이며, 이것이 포트 매핑이 필요한 이유입니다.

### 6.2 브라우저 접속 증거

**① http://localhost:8080**

![포트 8080 접속](docs/images/browser-8080.png)

**② http://localhost:8081 — 같은 이미지, 다른 포트**

![포트 8081 접속](docs/images/browser-8081.png)

**③ http://localhost:8082/env — 환경 변수 주입 결과 (보너스)**

![환경변수 확인](docs/images/browser-env.png)

```sh
docker run -d -p 8082:9090 -e NGINX_PORT=9090 -e APP_ENV=production --name web-9090 cody-web:1.0
```

```
$ curl -s http://localhost:8082/env
APP_ENV=production          ← 이미지 기본값 dev 를 덮어씀
NGINX_PORT=9090

$ docker exec web-9090 grep listen /etc/nginx/conf.d/default.conf
    listen       9090;      ← 설정 파일이 실제로 다시 생성됨
```

**이미지를 다시 빌드하지 않고** 실행 옵션만으로 포트와 모드를 바꿨습니다.

### 6.3 바인드 마운트 — 호스트 변경 전/후 비교

```sh
docker run -d -p 8083:8080 -v "$(pwd)/app/site:/usr/share/nginx/html:ro" --name web-bind cody-web:1.0
```

| | 8080 (이미지에 `COPY`) | 8083 (바인드 마운트) |
|---|---|---|
| **변경 전** | `<h1>개발 워크스테이션 구축</h1>` | `<h1>개발 워크스테이션 구축</h1>` |
| **호스트 `index.html` 수정 후** | `<h1>개발 워크스테이션 구축</h1>` (그대로) | `<h1>… — 바인드 마운트 반영 테스트</h1>` **즉시 반영** |

```
$ perl -pi -e 's|구축</h1>|구축 — 바인드 마운트 반영 테스트</h1>|' app/site/index.html

$ curl -s http://localhost:8080/ | grep "<h1>"
    <h1>개발 워크스테이션 구축</h1>

$ curl -s http://localhost:8083/ | grep "<h1>"
    <h1>개발 워크스테이션 구축 — 바인드 마운트 반영 테스트</h1>
```

**빌드도 재시작도 하지 않았는데** 마운트한 쪽만 바뀌었습니다.
`:ro`(읽기 전용) 옵션으로 컨테이너가 호스트 소스를 수정하는 것도 차단했습니다.

```
$ docker exec web-bind sh -c "echo test >> /usr/share/nginx/html/index.html"
sh: can't create /usr/share/nginx/html/index.html: Read-only file system
```

### 6.4 볼륨 영속성 — 컨테이너 삭제 전/후 비교

먼저 **볼륨이 없으면 데이터가 사라지는 것**을 대조군으로 확인했습니다.

```
$ docker exec novol cat /data/important.txt
중요한 사용자 데이터
$ docker rm -f novol && docker run -d --name novol ubuntu:24.04 sleep infinity
$ docker exec novol cat /data/important.txt
cat: /data/important.txt: No such file or directory     ← 소실
```

볼륨을 사용한 경우:

```sh
docker volume create cody-data
docker run -d --name vol-test1 -v cody-data:/data ubuntu:24.04 sleep infinity
docker exec vol-test1 sh -c 'echo "중요한 사용자 데이터" > /data/important.txt; date >> /data/important.txt'
```

```
[ 삭제 전 ]
$ docker exec vol-test1 cat /data/important.txt
중요한 사용자 데이터
Tue Jul 28 09:02:34 UTC 2026

$ docker rm -f vol-test1              ← 컨테이너 강제 삭제
$ docker volume ls
DRIVER    VOLUME NAME
local     cody-data                    ← 볼륨은 살아있음

[ 삭제 후 · 새 컨테이너에 같은 볼륨 연결 ]
$ docker run -d --name vol-test2 -v cody-data:/data ubuntu:24.04 sleep infinity
$ docker exec vol-test2 cat /data/important.txt
중요한 사용자 데이터
Tue Jul 28 09:02:34 UTC 2026           ← 날짜까지 그대로 유지 ✅
```

다른 이미지(alpine)에서도 동일한 볼륨에 접근됩니다.

```
$ docker run --rm -v cody-data:/data alpine sh -c "cat /data/important.txt"
중요한 사용자 데이터
Tue Jul 28 09:02:34 UTC 2026
두번째 컨테이너가 추가한 줄
```

### 6.5 운영 명령 확인

```
$ docker logs web-8080 | tail -2
127.0.0.1 - - [28/Jul/2026:08:43:12 +0000] "GET / HTTP/1.1" 200 1159 "-" "Wget" "-"

$ docker stats --no-stream
CONTAINER ID   NAME            CPU %   MEM USAGE / LIMIT   MEM %   PIDS
f9b3d044178e   ubuntu-daemon   0.00%   900KiB / 15.67GiB   0.01%   1

$ docker history cody-web:1.0     # 이미지 레이어 구조
$ docker ps -a / docker images / docker volume ls
```

전체 출력은 [`04-container-run.log`](docs/logs/04-container-run.log), [`05-build.log`](docs/logs/05-build.log)에 있습니다.

---

## 7. Git 설정 및 GitHub 연동

### 7.1 Git 설정

```
$ git config --get user.name
nan-park

$ git config --get user.email
nemyrmain@gmail.com

$ git config --get init.defaultBranch
main

$ git remote -v
origin  https://github.com/nan-park/cody-e1-1.git (fetch)
origin  https://github.com/nan-park/cody-e1-1.git (push)

$ git branch -vv
* main [origin/main] docs: 7단계 바인드 마운트/볼륨 실습 로그 및 학습 일지 추가
```

전체 출력은 [`08-git.log`](docs/logs/08-git.log)에 있습니다.

### 7.2 원격 반영(push) 확인

```
$ git push -u origin main
To https://github.com/nan-park/cody-e1-1.git
   c6554f3..7423097  main -> main
branch 'main' set up to track 'origin/main'.

$ git ls-remote --heads origin           # GitHub 쪽 실제 상태를 직접 조회
7423097245ff1399151a9337599d1b34744f1246        refs/heads/main

$ git status -sb
## main...origin/main                     # "앞에 N개" 표시 없음 = 로컬·원격 동기화
```

### 7.3 연동 증거 스크린샷

**① VSCode — GitHub 계정 로그인 및 저장소 연동**

![VSCode GitHub 연동](docs/images/vscode-github.png)

Source Control 패널에 커밋 그래프가 표시되고, `main` 브랜치 옆의 원격 동기화 아이콘과
하단 상태바의 브랜치 정보로 GitHub 저장소와 연결된 상태를 확인할 수 있습니다.

**② GitHub 저장소 페이지**

![GitHub 저장소](docs/images/github-repo.png)

`github.com/nan-park/cody-e1-1` (Public) — 커밋 이력, 소스(`app/`, `Dockerfile`),
문서(`docs/`), README 렌더링이 모두 반영된 상태입니다.

### 7.4 커밋 이력

커밋은 단계별로 나누어 남겼으며, 성격에 따라 `feat:` / `docs:` 접두어를 구분했습니다.

```
$ git log --oneline
db59192 docs: 7단계 바인드 마운트/볼륨 실습 로그 및 학습 일지 추가
b115263 docs: 포트 매핑 브라우저 접속 증거 스크린샷 추가
2db1cc4 docs: 6단계 포트 매핑 실습 로그 및 학습 일지 추가
5122076 docs: 5단계 이미지 빌드 실습 로그 및 학습 일지 추가
7592092 feat: nginx 기반 커스텀 웹서버 이미지 Dockerfile 및 소스 추가
5283703 docs: 4단계 컨테이너 실행/운영 실습 로그 및 학습 일지 추가
8bb8688 docs: 0~3단계 학습 일지 추가
1e3141d docs: 3단계 Docker 설치/데몬 점검 로그 추가
d4c2b47 docs: 2단계 파일/디렉토리 권한 실습 로그 추가
f16d00d docs: 1단계 터미널 기본 조작 실습 로그 추가
c6554f3 Add .gitignore
```

---

## 8. 트러블슈팅

### ① 컨테이너 안에서는 되는데 브라우저에서 접속이 안 됨

- **문제**: `docker ps`의 PORTS에 `8080/tcp`가 표시되고 컨테이너 내부 `wget`은 성공하는데,
  호스트에서 `curl http://localhost:8080/`이 종료 코드 7(연결 불가)로 실패.
- **원인 가설**: (a) nginx가 안 떠 있다 (b) 방화벽 (c) **포트가 실제로 열리지 않았다**
- **확인**:
  - `docker exec web-nomap wget -qO- http://127.0.0.1:8080/` → **정상 응답** → (a) 기각
  - `docker inspect ... .NetworkSettings.Networks` → 컨테이너 IP `192.168.215.2`, 호스트는 `10.13.2.6` → **서로 다른 네트워크**
  - 실행 명령에 `-p` 옵션이 없었음
- **해결**: `Dockerfile`의 `EXPOSE`는 **문서용 선언일 뿐 포트를 열지 않는다.**
  `docker run -p 8080:8080`으로 재실행하여 접속 성공. → [06-port.log](docs/logs/06-port.log)

### ② `port is already allocated` — 그리고 실패한 컨테이너가 남는 문제

- **문제**: 세 번째 컨테이너를 `-p 8080:8080`으로 띄우자 `Bind for :::8080 failed: port is already allocated` 발생.
- **원인 가설**: 호스트 포트 8080을 이미 다른 컨테이너가 점유
- **확인**: `docker ps`에서 `web-8080`이 `0.0.0.0:8080->8080/tcp`로 사용 중임을 확인.
  추가로 `docker ps -a` 결과 **실패한 컨테이너가 `Created` 상태로 남아 있음**을 발견
  (= `run`의 create는 성공하고 start에서 실패).
- **해결**: 다른 호스트 포트(`-p 8081:8080`) 사용. 남은 컨테이너는 `docker rm -f web-dup`으로 정리.
  방치하면 다음 실행 시 "이름이 이미 존재한다"는 별개의 에러가 발생. → [06-port.log](docs/logs/06-port.log)

### ③ 볼륨의 `Mountpoint` 경로가 호스트에 존재하지 않음

- **문제**: `docker volume inspect cody-data`가 `/var/lib/docker/volumes/cody-data/_data`를 알려주는데,
  macOS에서 `ls /var/lib/docker/volumes` 실행 시 `No such file or directory`.
- **원인 가설**: (a) 볼륨 생성 실패 (b) **경로가 호스트가 아닌 다른 곳 기준**
- **확인**:
  - `docker run --rm -v cody-data:/data alpine ls -l /data` → 파일이 정상 존재 → (a) 기각
  - `docker info`의 `OS: OrbStack`, 컨테이너 안 `uname -sr`이 `Linux 6.17.8-orbstack` (호스트는 `Darwin 24.6.0`)
  - 호스트 `uptime` 7시간 14분 vs 컨테이너 `uptime` 6시간 27분 → **서로 다른 시스템**
- **해결**: 해당 경로는 **OrbStack이 구동하는 리눅스 VM 내부** 기준. 정상 동작이며 조치 불필요.
  호스트에서 내용을 확인해야 할 때는 임시 컨테이너로 볼륨을 마운트해서 접근.
  → [07-mount-volume.log](docs/logs/07-mount-volume.log)

### ④ 태그 없는 `<none>` 이미지가 쌓임

- **문제**: 캐시 동작 확인을 위해 같은 태그로 여러 번 빌드한 뒤 `docker images`에 `<none>` 이미지 발견 (48.2MB).
- **원인 가설**: 같은 태그로 재빌드 시 **기존 이미지가 태그를 잃고 dangling 상태로 남음**
- **확인**: `docker images -f "dangling=true"` → 해당 이미지 1건 확인
- **해결**: `docker image prune -f`로 정리.
  실무에서는 CI가 반복 빌드하며 디스크를 잠식하는 원인이 되므로 주기적 정리가 필요. → [08-git.log](docs/logs/08-git.log)

### ⑤ `docker info` 실행 시 `WARNING` 출력

- **문제**: `docker info` 마지막에 `WARNING: DOCKER_INSECURE_NO_IPTABLES_RAW is set` 출력.
- **원인 가설**: (a) 설치 손상 (b) **OrbStack의 자체 네트워크 구현에 따른 안내**
- **확인**: `Server:` 섹션이 정상 응답하고 컨테이너 실행·포트 매핑 모두 정상 동작.
- **해결**: 에러가 아닌 **안내 메시지**. OrbStack이 자체 네트워크 스택을 사용하며 iptables raw 테이블 기능을 사용하지 않아 출력됨.
  실습 범위에서 조치 불필요. → [03-docker-check.log](docs/logs/03-docker-check.log)

### ⑥ 컨테이너 터미널에서 한글 입력이 깨짐

- **문제**: `docker exec -it ubuntu-daemon bash` 세션에서 한글을 입력하자 프롬프트 에코가 8진수 이스케이프로 깨져 표시됨.
- **원인 가설**: 컨테이너 이미지에 **UTF-8 로케일이 설정되어 있지 않음**
- **확인**: 출력 자체(`echo` 결과)는 정상이고 **입력 에코만** 깨짐 → 터미널 로케일 문제로 판단
- **해결**: 실습 로그는 영문으로 재작성. 필요 시 Dockerfile에 `ENV LANG=C.UTF-8` 추가 또는
  `docker exec -e LANG=C.UTF-8`로 주입하면 해결됨. → [04-container-run.log](docs/logs/04-container-run.log)

---

## 9. 재현 절차 (평가자용)

```sh
# 0) 사전 조건: OrbStack(또는 Docker Desktop) 실행 중
docker info | head -20            # Server: 섹션이 응답하면 정상

# 1) 저장소 클론
git clone https://github.com/nan-park/cody-e1-1.git
cd cody-e1-1

# 2) 커스텀 이미지 빌드
docker build -t cody-web:1.0 .
docker images | grep cody-web

# 3) 포트 매핑 실행 (2개)
docker run -d -p 8080:8080 --name web-8080 cody-web:1.0
docker run -d -p 8081:8080 --name web-8081 cody-web:1.0
curl http://localhost:8080/healthz     # ok
curl http://localhost:8081/healthz     # ok
# 브라우저에서 http://localhost:8080 , http://localhost:8081 접속

# 4) 환경변수 주입 (보너스)
docker run -d -p 8082:9090 -e NGINX_PORT=9090 -e APP_ENV=production --name web-9090 cody-web:1.0
curl http://localhost:8082/env         # APP_ENV=production / NGINX_PORT=9090

# 5) 바인드 마운트 (실시간 반영)
docker run -d -p 8083:8080 -v "$(pwd)/app/site:/usr/share/nginx/html:ro" --name web-bind cody-web:1.0
curl -s http://localhost:8083/ | grep "<h1>"
#   app/site/index.html 의 <h1> 문구를 수정한 뒤 위 명령을 다시 실행하면 즉시 반영됨

# 6) 볼륨 영속성
docker volume create cody-data
docker run -d --name vol-test1 -v cody-data:/data ubuntu:24.04 sleep infinity
docker exec vol-test1 sh -c 'echo hello > /data/important.txt'
docker rm -f vol-test1                                    # 컨테이너 삭제
docker run -d --name vol-test2 -v cody-data:/data ubuntu:24.04 sleep infinity
docker exec vol-test2 cat /data/important.txt             # hello  ← 데이터 유지

# 7) 정리
docker rm -f web-8080 web-8081 web-9090 web-bind vol-test2
docker volume rm cody-data
docker image prune -f
```

### 환경 의존적인 부분 (주의사항)

| 항목 | 이 저장소 기준 | 다른 환경에서 |
|---|---|---|
| 컨테이너 런타임 | OrbStack | Docker Desktop / 리눅스 native 모두 동일하게 동작 |
| 바인드 마운트 경로 | `$(pwd)/app/site` | **절대경로 필요.** 상대경로를 쓰면 볼륨 이름으로 해석됨 |
| 호스트 포트 | 8080~8083 | 사용 중이면 `-p <다른포트>:8080`으로 변경 |
| CPU 아키텍처 | `x86_64` | arm64 환경에서도 동작(멀티아키 베이스). 필요 시 `--platform` 지정 |

---

## 10. 학습 정리 (과제 목표 답안)

**① 절대 경로와 상대 경로의 차이**
절대경로는 최상위 `/`부터 시작하는 전체 주소라 어디서 실행해도 같은 곳을 가리키고,
상대경로는 현재 위치(`pwd`) 기준이라 이동하면 표기가 달라진다.
같은 파일이 `practice`에서는 `./src/hello.txt`, `src`로 이동하면 `./hello.txt`가 된다.

**② 파일 권한의 의미와 755/644의 해석**
`r/w/x`는 읽기·쓰기·실행이고 각각 `4/2/1` 값을 가진다. 이를 소유자·그룹·기타 3묶음으로 더한 것이 숫자 표기다.
`755 = rwxr-xr-x`, `644 = rw-r--r--`.
단 **디렉토리에서는 의미가 달라져** `r`은 목록 조회, `w`는 파일 생성/삭제, `x`는 진입(cd)을 뜻한다.

**③ 기존 Dockerfile 기반 커스텀 이미지 제작**
`FROM nginx:1.27-alpine`으로 시작해 `COPY`로 정적 콘텐츠와 설정 템플릿을 얹고,
`ENV`·`EXPOSE`·`HEALTHCHECK`·`LABEL`을 추가해 `cody-web:1.0`을 빌드했다.
Dockerfile 명령 한 줄이 이미지의 층 하나가 되며, 한 층이 바뀌면 그 위 층은 캐시가 무효화된다.

**④ 포트 매핑이 필요한 이유**
컨테이너는 자기만의 네트워크 네임스페이스를 가져 호스트와 분리되어 있다.
`EXPOSE`는 문서 선언일 뿐이고, `-p 호스트:컨테이너`로 통로를 뚫어야 외부에서 접근할 수 있다.
또한 여러 컨테이너가 내부적으로 같은 포트를 쓰더라도 호스트 포트만 다르게 매핑하면 동시에 서비스할 수 있다.

**⑤ Docker 볼륨(영속 데이터)**
컨테이너에서 만든 파일은 컨테이너의 쓰기 층에 저장되어 `docker rm` 시 함께 사라진다.
볼륨은 Docker가 관리하는 독립 저장소로, 컨테이너를 삭제해도 데이터가 남고 다른 컨테이너·다른 이미지에서도 연결해 쓸 수 있다.
개발용 소스 연결에는 바인드 마운트, DB·업로드 파일 등 운영 데이터에는 볼륨을 쓴다.

**⑥ Git과 GitHub의 역할 차이**
Git은 내 컴퓨터에서 동작하는 **버전 관리 프로그램**으로 인터넷 없이도 커밋·되돌리기가 가능하다.
GitHub는 그 저장소를 올려두고 공유·협업하는 **원격 플랫폼**이다.
`git commit`까지는 로컬에만 기록되고, `git push`를 해야 GitHub에 반영된다.

---

## 11. 보너스 과제 — Docker Compose

`docker run`의 긴 옵션들을 [`docker-compose.yml`](docker-compose.yml)로 옮겨,
**웹 서버(`web`) + 캐시 서버(`cache`)** 두 서비스를 함께 실행했습니다.

```sh
docker compose up -d      # 실행 (네트워크·볼륨까지 자동 생성)
docker compose ps         # 상태
docker compose logs       # 전체 서비스 로그 합쳐 보기
docker compose down       # 종료 (볼륨은 유지)
```

### 컨테이너 간 통신 (서비스 디스커버리)

```
$ docker compose exec web getent hosts cache
192.168.97.2      cache                      ← 서비스 이름이 IP로 해석됨

$ docker compose exec web sh -c 'echo "PING" | nc cache 6379'
+PONG                                        ← 웹 → 캐시 통신 성공

$ curl -s --max-time 3 http://localhost:6379
종료코드=7                                    ← 호스트에서는 접근 불가
```

`cache`에는 `ports:`를 두지 않아 **외부에 노출되지 않고 내부에서만** 접근됩니다.
컨테이너 IP는 재시작 시 바뀌므로, 애플리케이션은 IP가 아니라 **서비스 이름**으로 연결합니다.

### 환경 변수 주입

```
$ curl -s http://localhost:8090/env
APP_ENV=compose                              ← docker-compose.yml 의 environment 값
NGINX_PORT=8080
```

### 종료 후 데이터 유지

```
$ docker compose down && docker compose up -d
$ docker compose exec cache redis-cli get greeting
hello-from-compose                           ← 이름 있는 볼륨 덕분에 유지 ✅
```

`down`은 컨테이너·네트워크만 삭제하고 볼륨은 남깁니다. (데이터까지 지우려면 `down -v`)

전체 로그: [`09-compose.log`](docs/logs/09-compose.log) · 정리: [학습 일지 9단계](docs/learning/09-compose.md)

| 보너스 항목 | 상태 |
|---|---|
| Docker Compose 기초 (단일 서비스 실행) | ✅ |
| Compose 멀티 컨테이너 + 컨테이너 간 통신 | ✅ |
| Compose 운영 명령 (`up`/`down`/`ps`/`logs`) | ✅ |
| 환경 변수 활용 (설정과 코드의 분리) | ✅ |
| GitHub SSH 키 설정 | ✅ |

### GitHub SSH 키 설정

HTTPS(토큰) 대신 SSH 키 쌍으로 인증하도록 전환했습니다.

```sh
ssh-keygen -t ed25519 -C "nan-park@codyssey-e1-1" -f ~/.ssh/id_ed25519 -N ""
```

```
$ ls -l ~/.ssh
-rw-------  419  id_ed25519        ← 개인키 · 권한 600 (남이 읽을 수 있으면 SSH가 접속 거부)
-rw-r--r--  104  id_ed25519.pub    ← 공개키 · 권한 644

$ ssh -T git@github.com
Hi nan-park! You've successfully authenticated, but GitHub does not provide shell access.

$ git remote set-url origin git@github.com:nan-park/cody-e1-1.git
$ git remote -v
origin  git@github.com:nan-park/cody-e1-1.git (fetch)
origin  git@github.com:nan-park/cody-e1-1.git (push)
```

**2단계에서 배운 `600` 권한이 여기서 실제로 강제됩니다.** `ssh-keygen`은 umask(022)를 따르지 않고
개인키를 직접 600으로 생성하며, 권한이 열려 있으면 SSH가 접속을 거부합니다.

공개키는 GitHub가 `github.com/<사용자명>.keys`로 공개하는 정보라 노출되어도 안전하지만,
**개인키는 저장소·로그·스크린샷 어디에도 포함하지 않았습니다.**

전체 로그: [`10-ssh.log`](docs/logs/10-ssh.log) · 정리: [학습 일지 10단계](docs/learning/10-ssh.md)

---

## 12. 학습 일지

각 단계의 개념 정리, 헷갈리기 쉬운 지점, 진행 중 나온 질문과 답을 별도로 정리했습니다.

| 단계 | 문서 | 핵심 주제 |
|---|---|---|
| 0 | [오리엔테이션](docs/learning/00-orientation.md) | 미션의 목적, 이미지 vs 컨테이너 |
| 1 | [터미널 기본기](docs/learning/01-terminal.md) | 절대경로 vs 상대경로 |
| 2 | [파일 권한](docs/learning/02-permission.md) | r/w/x, 755·644, 디렉토리의 x |
| 3 | [Docker 점검](docs/learning/03-docker-check.md) | VM vs 컨테이너, CLI/데몬 구조 |
| 4 | [컨테이너 실행과 운영](docs/learning/04-container-run.md) | exec vs attach, PID 1, 커널 |
| 5 | [Dockerfile과 이미지 빌드](docs/learning/05-build.md) | 레이어와 캐시, 빌드/실행 시점 |
| 6 | [포트 매핑](docs/learning/06-port.md) | 네트워크 격리, `-p` |
| 7 | [바인드 마운트와 볼륨](docs/learning/07-mount-volume.md) | 실시간 반영, 데이터 영속성 |
| 9 | [Docker Compose](docs/learning/09-compose.md) *(보너스)* | 서비스 디스커버리, 멀티 컨테이너 |
| 10 | [GitHub SSH 키](docs/learning/10-ssh.md) *(보너스)* | 공개키/개인키, 권한 600의 이유 |

---

## 13. 보안 / 개인정보

- 로그·스크린샷에 토큰, 비밀번호, 개인키, 인증 코드가 포함되지 않도록 확인했습니다.
- `git config --list` 출력은 `credential`/`token`/`password` 항목을 제외하고 기록했습니다.
- `.gitignore`로 로컬 설정 파일(`.claude/settings.local.json`)과 `.DS_Store`를 제외했습니다.
- 스크린샷은 주소창과 응답 화면만 포함하며, 계정 정보가 노출되지 않는 범위로 캡처했습니다.
