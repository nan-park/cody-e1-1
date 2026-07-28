# 10단계 · GitHub SSH 키 설정 (보너스)

> 실습 로그: [`docs/logs/10-ssh.log`](../logs/10-ssh.log)

## 인증 방식이 두 가지인 이유

```
origin  https://github.com/nan-park/cody-e1-1.git   ← 지금까지 쓰던 방식
```

HTTPS는 **"내가 누구인지"를 매번 증명**해야 한다. 예전엔 비밀번호, 지금은 **토큰**(길고 복잡한 문자열)을 쓴다.
편하지만 토큰이 유출되면 그대로 계정이 뚫린다.

```
HTTPS :  "제 비밀번호는 abc123입니다"           → 비밀을 상대에게 보냄
SSH   :  "이 자물쇠를 열 수 있는 열쇠가 있습니다"  → 비밀은 내 컴퓨터 밖으로 안 나감
```

## 공개키와 개인키

SSH 키는 **항상 쌍**으로 만들어진다.

| | 역할 | 비유 | 어디에 두나 |
|---|---|---|---|
| **공개키** (`.pub`) | 잠그는 쪽 | **자물쇠** | GitHub에 등록 (남에게 줘도 안전) |
| **개인키** | 여는 쪽 | **열쇠** | 내 컴퓨터에만 (**절대 유출 금지**) |

자물쇠는 나눠줘도 괜찮다. 그걸 열 열쇠는 나만 갖고 있으니까.
GitHub는 내가 등록한 자물쇠로 문제를 내고, 내 컴퓨터가 열쇠로 풀어 신원을 증명한다.

> **공개키는 정말 공개해도 안전하다.** GitHub는 모든 사용자의 공개키를
> `github.com/사용자명.keys` 주소로 누구나 볼 수 있게 제공한다.
> 반대로 개인키(`BEGIN OPENSSH PRIVATE KEY`로 시작)는 **어디에도 붙여넣으면 안 된다.**

## 키 생성

```sh
ssh-keygen -t ed25519 -C "nan-park@codyssey-e1-1" -f ~/.ssh/id_ed25519 -N ""
           └───┬────┘ └────────┬──────────┘ └────────┬────────┘ └┬┘
           키 알고리즘        주석(라벨)            저장 파일     암호문구
```

| 옵션 | 의미 |
|---|---|
| `-t ed25519` | 키 알고리즘. 예전의 `rsa`보다 **짧으면서 더 안전하고 빠르다** (공개키가 한 줄에 들어감, RSA는 6~7줄) |
| `-C` | 주석(라벨). 암호와 무관하며 **"어느 기기/용도의 키인지"** 구분용 |
| `-f` | 저장할 파일 경로 |
| `-N ""` | 암호문구 없음 |

> **`-N ""`에 대한 솔직한 설명**: 암호문구를 걸면 키 파일이 유출돼도 한 번 더 막아준다.
> 다만 푸시할 때마다 입력해야 해서 실습에서는 생략했다.
> 나중에 `ssh-keygen -p -f ~/.ssh/id_ed25519`로 언제든 추가할 수 있고,
> macOS는 키체인에 저장해 자동 입력되게 할 수 있다.

## ⭐ 2단계의 권한이 여기서 강제된다

```
$ ls -l ~/.ssh
-rw-------  419  id_ed25519        ← 개인키 (열쇠) · 권한 600
-rw-r--r--  104  id_ed25519.pub    ← 공개키 (자물쇠) · 권한 644

$ stat -f "%Sp %Lp %N" ~/.ssh/id_ed25519
-rw------- 600 /Users/nika.dev02147536/.ssh/id_ed25519
```

| 파일 | 권한 | 이유 |
|---|---|---|
| 개인키 | **600** | 나만 읽고 쓸 수 있어야 함. **남이 읽을 수 있으면 SSH가 접속을 거부한다** |
| 공개키 | 644 | 남이 읽어도 되는 정보라 기본값 그대로 |

`ssh-keygen`이 **알아서 600으로 만든다.** umask(022)를 따랐다면 644가 됐을 텐데,
보안이 중요한 파일이라 프로그램이 직접 권한을 조여둔 것이다.

실수로 `chmod 644 ~/.ssh/id_ed25519`를 하면 다음 접속에서:

```
Permissions 0644 for '/Users/.../id_ed25519' are too open.
It is required that your private key files are NOT accessible by others.
```

> 2단계에서 "600은 나중에 SSH 키에서 강제로 요구된다"고 적어둔 것이 실제로 확인됐다.

## GitHub 등록 및 연결 테스트

공개키를 https://github.com/settings/keys 에 등록한 뒤:

```
$ ssh -T git@github.com
Warning: Permanently added 'github.com' (ED25519) to the list of known hosts.
Hi nan-park! You've successfully authenticated, but GitHub does not provide shell access.
```

**`Hi nan-park!`** 가 나오면 성공. GitHub가 내 키를 보고 **누구인지 알아본 것**이다.
뒤의 "shell access는 제공하지 않는다"는 정상 안내다(GitHub는 Git 전송용으로만 SSH를 연다).

### `known_hosts`는 뭔가

```
$ ssh-keygen -lf ~/.ssh/known_hosts
256 SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU github.com (ED25519)
```

**인증은 양방향이다.** 나만 신원을 증명하는 게 아니라, 상대 서버도 자기 공개키로 신원을 증명한다.
처음 접속 시 그 값을 `known_hosts`에 저장해 두고, 다음부터 **값이 바뀌면 경고**한다
(중간에서 누가 가로채는 상황을 잡아내기 위해).

## 원격 주소를 SSH로 변경

```
$ git remote -v
origin  https://github.com/nan-park/cody-e1-1.git      ← 변경 전

$ git remote set-url origin git@github.com:nan-park/cody-e1-1.git

$ git remote -v
origin  git@github.com:nan-park/cody-e1-1.git          ← 변경 후
```

주소 형식이 다르다.

```
HTTPS :  https://github.com/nan-park/cody-e1-1.git
SSH   :  git@github.com:nan-park/cody-e1-1.git
         └┬┘ └────┬────┘ └────────┬─────────┘
       사용자    호스트         저장소 경로
```

SSH 주소의 `git@`은 **GitHub 서버의 계정 이름**이다. 모든 사용자가 이 `git` 계정으로 접속하고,
**어떤 키로 접속했는지**를 보고 GitHub가 누구인지 구분한다.

## HTTPS vs SSH 정리

| | HTTPS | SSH |
|---|---|---|
| 인증 수단 | 토큰(비밀번호 대체) | 키 쌍 |
| 비밀이 네트워크로 나가나 | **나감**(토큰 전송) | **안 나감** |
| 최초 설정 | 간단 | 키 생성 + 등록 필요 |
| 이후 사용 | 토큰 입력/저장 필요 | 자동 |
| 방화벽 | 대부분 통과(443) | 22번 포트가 막힌 곳도 있음 |
| 유출 시 | 토큰 폐기 | 해당 공개키만 삭제 |

> 회사망에서 22번 포트가 막힌 경우 SSH가 안 될 수 있는데,
> 그럴 땐 GitHub의 `ssh.github.com:443` 우회 설정을 쓴다.

## 헷갈리기 쉬운 지점

### 1. 키를 다시 만들면 기존 등록은 무효가 된다

`~/.ssh/id_ed25519`를 덮어쓰면 GitHub에 등록된 공개키와 짝이 안 맞아 인증이 실패한다.
새로 만들면 **GitHub에도 새 공개키를 다시 등록**해야 한다.

### 2. 키는 계정이 아니라 "기기"에 대응한다

노트북·데스크톱을 함께 쓰면 각 기기에서 키를 만들어 **여러 개를 등록**하는 게 정상이다.
그래서 `-C` 주석에 기기 이름을 적어두면 나중에 구분하기 쉽다.

### 3. 이미 클론한 저장소는 주소가 자동으로 안 바뀐다

`git remote set-url`로 직접 바꿔야 한다. 새로 클론할 때는 GitHub의 **Code → SSH** 탭 주소를 복사한다.

## 스스로 점검하는 질문

1. 공개키를 GitHub에 올려도 안전한 이유는?
2. 개인키 권한이 644면 무슨 일이 생기나? 왜 그렇게 막나?
3. `ssh -T git@github.com`의 `git@`은 무엇인가?
4. `known_hosts`는 무엇을 저장하며 왜 필요한가?
5. HTTPS 대신 SSH를 쓸 때의 장단점은?

## 보너스 체크

- [x] SSH 키 쌍 생성 (`ed25519`)
- [x] 개인키 600 / 공개키 644 권한 확인
- [x] GitHub에 공개키 등록 및 `ssh -T`로 인증 확인 (`Hi nan-park!`)
- [x] 원격 주소를 HTTPS → SSH로 변경하고 통신 확인
