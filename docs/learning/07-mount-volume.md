# 7단계 · 바인드 마운트와 볼륨

> 실습 로그: [`docs/logs/07-mount-volume.log`](../logs/07-mount-volume.log)

---

# 7-1. 바인드 마운트 — "저장하면 바로 반영"

## 문제: 한 글자 고치는 데 빌드가 필요하다

```
index.html 수정 → docker build → docker rm → docker run → 확인
                  └────────── 매번 반복 ──────────┘
```

`COPY`는 **빌드 시점에 파일을 이미지 안으로 복사**한다. 이미지 안의 파일은 내 맥의 원본과 아무 관계 없는 **사본**이다.

## 실행 명령

```sh
docker run -d -p 8083:8080 \
  -v "$(pwd)/app/site:/usr/share/nginx/html:ro" \
  --name web-bind cody-web:1.0
     └────────┬────────┘ └──────────┬─────────┘ └┬┘
       내 맥의 폴더            컨테이너 안 경로    읽기전용
```

또 **`호스트:컨테이너`** 순서. (`-p`, `COPY`와 같은 규칙)

> **`$(pwd)`를 쓴 이유**: 바인드 마운트의 호스트 경로는 **반드시 절대경로**여야 한다.
> `-v ./app/site:...` 처럼 상대경로로 쓰면 Docker가 이를 **경로가 아니라 "볼륨 이름"으로 오해**한다.
> 1단계에서 배운 `pwd`가 여기서 쓰인다.

## ⭐ 변경 전/후 비교 (같은 이미지의 두 컨테이너)

```
[ 변경 전 ]
  8080 (이미지에 COPY된 파일)  →  <h1>개발 워크스테이션 구축</h1>
  8083 (내 맥 폴더를 마운트)   →  <h1>개발 워크스테이션 구축</h1>        같음

           ↓  내 맥의 index.html 만 수정 (빌드 X, 재시작 X)

[ 변경 후 ]
  8080 (이미지에 COPY된 파일)  →  <h1>개발 워크스테이션 구축</h1>           그대로
  8083 (내 맥 폴더를 마운트)   →  <h1>… — 바인드 마운트 반영 테스트</h1>    즉시 반영 ✅
```

컨테이너 안에서 직접 확인해도 같다.

```
$ docker exec web-bind grep "<h1>" /usr/share/nginx/html/index.html
    <h1>개발 워크스테이션 구축 — 바인드 마운트 반영 테스트</h1>   ← 내 맥 파일이 그대로 보임

$ docker exec web-8080 grep "<h1>" /usr/share/nginx/html/index.html
    <h1>개발 워크스테이션 구축</h1>                                ← 빌드 당시의 사본
```

파일을 되돌리자 8083도 즉시 원래대로 돌아왔다.

## 무슨 일이 일어난 건가

```
      [ COPY 방식 - web-8080 ]              [ 바인드 마운트 - web-bind ]

  내 맥 index.html                        내 맥 index.html
        │ (빌드 시점에 한 번 복사)                │
        ↓                                        │ (실시간 연결)
  이미지 안 사본  ← 이후 원본과 무관              │
        ↓                                        ↓
   컨테이너가 사본을 서빙                  컨테이너가 원본을 직접 봄
```

바인드 마운트는 **컨테이너 안의 특정 폴더를 내 맥의 폴더로 "덮어씌우는"** 것.
이미지 안에 있던 `/usr/share/nginx/html`은 **가려지고**, 그 자리에 내 맥의 `app/site`가 나타난다.
사본이 아니라 **같은 파일**을 양쪽이 보고 있다.

## `:ro` 가 막아준 것

```
$ docker exec web-bind sh -c "echo test >> /usr/share/nginx/html/index.html"
sh: can't create /usr/share/nginx/html/index.html: Read-only file system
```

마운트는 **양방향**이라 `:ro`가 없으면 컨테이너 안 프로세스가 내 프로젝트 파일을 고치거나 지울 수 있다.
2단계의 권한 원칙(**필요한 만큼만**)이 여기서 다시 적용된다.

## 실무 기준

| 상황 | 방식 |
|---|---|
| **개발 중** | 바인드 마운트 — 코드를 수정하며 바로 확인 |
| **배포** | 이미지에 `COPY` — 어디서든 같은 결과 보장 |

Dockerfile은 `COPY`를 유지하고 개발할 때만 `-v`를 덧붙이는 구조가 정석.

> **주의**: 맥에서는 바인드 마운트가 **VM 경계를 넘어야 해서 리눅스보다 느리다**(3단계 참고).

---

# 7-2. 볼륨 — "컨테이너를 지워도 남는 데이터"

## 문제 재현: 볼륨 없이 쓰면 사라진다

```
$ docker exec novol cat /data/important.txt
중요한 사용자 데이터                                    ← 있었는데

$ docker rm -f novol && docker run -d --name novol ubuntu:24.04 sleep infinity
$ docker exec novol cat /data/important.txt
cat: /data/important.txt: No such file or directory      ← 없어졌다
```

### 왜? — 컨테이너의 쓰기 층

```
   ┌────────────────────────┐
   │  컨테이너 쓰기 층 ✏️     │  ← 컨테이너 안에서 만든/고친 파일이 전부 여기
   ├────────────────────────┤
   │  이미지 층 (읽기 전용)   │  ← 여러 컨테이너가 공유, 절대 안 바뀜
   │  이미지 층 (읽기 전용)   │
   └────────────────────────┘
```

**쓰기 층은 컨테이너와 운명을 같이한다.** `docker rm` = 쓰기 층도 삭제.

> 이건 버그가 아니라 **의도된 설계**다. 컨테이너는 언제든 버리고 새로 만들 수 있어야(disposable) 하니까.
> 대신 **살아남아야 할 데이터는 컨테이너 바깥에 두라**는 것이 Docker의 답 = 볼륨.

## 볼륨 사용법

```sh
docker volume create cody-data                                    # ① 생성
docker run -d --name vol-test1 -v cody-data:/data ubuntu:24.04 sleep infinity   # ② 연결
                                  └───┬───┘ └─┬┘
                                 볼륨 이름   컨테이너 안 경로
```

### 바인드 마운트와 문법 구별법

```
-v /Users/.../app/site:/usr/share/nginx/html    ← / 로 시작 = 경로 = 바인드 마운트
-v cody-data:/data                              ← 그냥 이름 = 볼륨
```

**슬래시로 시작하느냐**가 기준. `docker inspect`에도 다르게 표시된다.

```
바인드 마운트 :  Type=bind    / Source=/Users/.../app/site
볼륨         :  Type=volume  / Name=cody-data
```

## ⭐ 삭제 전/후 비교 — 영속성 증명

```
[ 삭제 전 ]
$ docker exec vol-test1 cat /data/important.txt
중요한 사용자 데이터
Tue Jul 28 09:02:34 UTC 2026

$ docker rm -f vol-test1                    ← 컨테이너 강제 삭제
$ docker ps -a
NAMES      STATUS
web-bind   Up ...                            ← vol-test1 은 완전히 사라짐
web-8080   Up ...

$ docker volume ls
DRIVER    VOLUME NAME
local     cody-data                          ← 볼륨은 그대로 살아있다 ✅

[ 삭제 후 - 새 컨테이너에 같은 볼륨 연결 ]
$ docker run -d --name vol-test2 -v cody-data:/data ubuntu:24.04 sleep infinity
$ docker exec vol-test2 cat /data/important.txt
중요한 사용자 데이터
Tue Jul 28 09:02:34 UTC 2026                  ← 날짜까지 그대로 ✅

$ docker exec vol-test2 sh -c "echo \"두번째 컨테이너가 추가한 줄\" >> /data/important.txt"
$ docker exec vol-test2 cat /data/important.txt
중요한 사용자 데이터
Tue Jul 28 09:02:34 UTC 2026
두번째 컨테이너가 추가한 줄                     ← 이어서 쓰기도 됨
```

## 이미지가 달라도 접근 가능

```
$ docker run --rm -v cody-data:/data alpine sh -c "ls -l /data && cat /data/important.txt"
-rw-r--r--    1 root     root            99 Jul 28 09:02 important.txt
중요한 사용자 데이터
Tue Jul 28 09:02:34 UTC 2026
두번째 컨테이너가 추가한 줄
```

**우분투 컨테이너가 만든 파일을 알파인 컨테이너가 읽었다.**
볼륨은 특정 컨테이너나 이미지에 묶이지 않은 **독립된 저장소**다.
(2단계의 `ls -l` 읽기가 여기서도 쓰인다: 644, root 소유, 99바이트가 그대로 유지)

## 볼륨은 실제로 어디 있나

```
$ docker volume inspect cody-data
"Mountpoint": "/var/lib/docker/volumes/cody-data/_data"

$ ls /var/lib/docker/volumes
ls: /var/lib/docker/volumes: No such file or directory     ← 내 맥에는 없다!
```

그 경로는 **OrbStack의 리눅스 VM 안**에 있다(3단계 참고).

> 이게 볼륨의 특징을 보여준다. **볼륨은 Docker가 알아서 관리하는 저장소**라 사용자는 위치를 몰라도 되고,
> 이름(`cody-data`)으로만 부르면 된다. 반면 바인드 마운트는 내가 경로를 지정하고 직접 관리한다.

## 바인드 마운트 vs 볼륨

| | 바인드 마운트 | 볼륨 |
|---|---|---|
| 지정 방식 | `-v /절대경로:/컨테이너경로` | `-v 이름:/컨테이너경로` |
| 실제 위치 | **내가 정한** 호스트 폴더 | **Docker가 관리**하는 영역 |
| 호스트에서 직접 편집 | 쉬움 | 어려움 (VM 안) |
| 성능 (맥/윈도우) | 느림 (VM 경계 통과) | 빠름 |
| 주 용도 | **개발 중 소스코드 연결** | **DB·업로드 파일 등 운영 데이터** |
| 백업/이전 | 폴더 복사 | `docker volume` 명령 |

> **바인드 마운트는 "내 파일을 컨테이너에 보여주는 것"**,
> **볼륨은 "컨테이너의 데이터를 밖에 보관하는 것"**. 방향이 반대다.

## 헷갈리기 쉬운 지점

### 1. 볼륨은 컨테이너를 지워도 자동 삭제되지 않는다

안전하지만 **쓰지 않는 볼륨이 쌓여 디스크를 먹는다.**

```sh
docker volume ls              # 목록 확인
docker volume rm cody-data    # 개별 삭제
docker volume prune           # 아무도 안 쓰는 볼륨 일괄 삭제 (되돌릴 수 없음!)
```

### 2. DB를 볼륨 없이 띄우면 재생성 시 데이터가 전부 날아간다

실무에서 실제로 벌어지는 사고. 공식 이미지 문서에는 어느 경로를 볼륨으로 잡아야 하는지 반드시 적혀 있다.

```sh
docker run -d -v pgdata:/var/lib/postgresql/data postgres:16   # 볼륨 필수
docker run -d -v $(pwd)/src:/app/src node:22                   # 개발용 바인드 마운트
```

### 3. 마운트하면 원래 있던 내용은 "가려진다"

삭제되는 게 아니라 **가려질 뿐**이다. 마운트를 떼면 이미지 안의 원래 파일이 다시 보인다.

## 스스로 점검하는 질문

1. `docker rm` 으로 컨테이너를 지우면 그 안에서 만든 파일은 어떻게 되나? 왜?
2. `-v abc:/data` 와 `-v /home/me/abc:/data` 의 차이는?
3. 개발 중 소스코드에는 왜 볼륨이 아니라 바인드 마운트를 쓰나?
4. `:ro` 를 붙이는 이유는?
5. 볼륨의 실제 저장 위치가 맥에서 안 보이는 이유는?

## 7단계 체크

- [x] 바인드 마운트: 실행 명령 + **호스트 변경 전/후 비교**
- [x] `:ro` 옵션으로 컨테이너의 쓰기 차단 확인
- [x] 볼륨 생성 / 연결 / 검증 명령
- [x] **컨테이너 삭제 전/후 데이터 비교로 영속성 증명**
- [x] 볼륨 없이 쓰면 데이터가 사라지는 것도 대조 실험으로 확인
