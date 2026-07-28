# 학습 일지

미션을 진행하며 단계별로 **배운 개념 / 헷갈렸던 지점 / 실제로 던진 질문과 답**을 기록한 폴더.
실행 명령과 출력 원본은 [`docs/logs/`](../logs)에 별도로 있다.

| 단계 | 일지 | 실습 로그 | 핵심 주제 |
|---|---|---|---|
| 0 | [오리엔테이션](00-orientation.md) | – | 미션의 목적, 이미지 vs 컨테이너 |
| 1 | [터미널 기본기](01-terminal.md) | [01-terminal.log](../logs/01-terminal.log) | 절대경로 vs 상대경로, 기본 명령 |
| 2 | [파일 권한](02-permission.md) | [02-permission.log](../logs/02-permission.log) | r/w/x, 755·644의 원리, 디렉토리의 x |
| 3 | [Docker 점검](03-docker-check.md) | [03-docker-check.log](../logs/03-docker-check.log) | VM vs 컨테이너, CLI/데몬 구조, 아키텍처 |
| 4 | [컨테이너 실행과 운영](04-container-run.md) | [04-container-run.log](../logs/04-container-run.log) | exec vs attach, PID 1, 커널, 생명주기 |
| 5 | [Dockerfile과 이미지 빌드](05-build.md) | [05-build.log](../logs/05-build.log) | 레이어와 캐시, 빌드/실행 시점, FROM 상속 |
| 6 | [포트 매핑](06-port.md) | [06-port.log](../logs/06-port.log) | 네트워크 격리, `-p 호스트:컨테이너` |
| 7 | [바인드 마운트와 볼륨](07-mount-volume.md) | [07-mount-volume.log](../logs/07-mount-volume.log) | 실시간 반영, 데이터 영속성 |
| 8 | (README 참고) | [08-git.log](../logs/08-git.log) | Git 설정, GitHub 연동, 제출 |
| 9 | [Docker Compose](09-compose.md) *(보너스)* | [09-compose.log](../logs/09-compose.log) | 서비스 디스커버리, 멀티 컨테이너 |
| 10 | [GitHub SSH 키](10-ssh.md) *(보너스)* | [10-ssh.log](../logs/10-ssh.log) | 공개키/개인키, 권한 600의 이유 |

## 단계별 한 줄 요약

- **0단계** — 이 미션은 성능이 아니라 **환경 불일치**를 푸는 작업이다.
- **1단계** — 절대경로는 어디서 실행해도 같은 곳, 상대경로는 **내가 이동하면 달라진다**.
- **2단계** — `r/w/x = 4/2/1`을 3묶음으로 더한 게 숫자 표기. 단 **디렉토리에서는 의미가 바뀐다**(`x` = 진입).
- **3단계** — `--version`은 CLI 확인일 뿐, **데몬 확인은 `docker info`의 `Server:` 섹션**으로 한다.
- **4단계** — 컨테이너는 **PID 1이 살아있는 동안만** 산다. `exec`은 면회객, `attach`는 환자 본인.
- **5단계** — Dockerfile 한 줄이 층 하나. **층이 깨지면 그 위가 전부 다시 만들어진다.**
- **6단계** — `EXPOSE`는 문패, `-p`는 문. 내부 포트는 같아도 되고 **바깥 포트만 달라야** 한다.
- **7단계** — 바인드 마운트는 **내 파일을 보여주는 것**, 볼륨은 **컨테이너 데이터를 밖에 보관하는 것**.
- **8단계** — `git commit`은 로컬까지, **GitHub 반영은 `git push`** 부터.
- **9단계** — Compose는 새 기술이 아니라 **`run` 옵션을 파일로 옮긴 것**. 서비스 이름이 곧 주소다.
- **10단계** — 공개키는 **자물쇠**(공개해도 안전), 개인키는 **열쇠**(600 권한 강제).

## 아직 남은 궁금증 / 다음에 확인할 것

- [x] 이미지가 "층(layer)"으로 저장된다는 게 실제로 어떤 의미인지 → **5단계에서 확인**
      (`docker history`로 확인. Dockerfile 명령 1줄 = 층 1개, 캐시 단위이기도 하다)
- [x] 컨테이너를 지우면 안의 데이터는 어떻게 되는지 → **7단계에서 확인**
      (컨테이너의 쓰기 층과 함께 사라진다. 살아남아야 할 데이터는 볼륨에 둔다)
- [x] `docker run`의 `-d`, `-it` 옵션이 각각 무슨 차이를 만드는지 → **4단계에서 확인**
      (`-it`는 앞에서 붙잡고, `-d`는 뒤로 떼어놓는다)
