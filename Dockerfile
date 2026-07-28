# ─────────────────────────────────────────────────────────────
#  Codyssey Mission 1 · 커스텀 웹 서버 이미지
#
#  기존 베이스 이미지 : nginx:1.27-alpine (공식 이미지)
#  커스텀 포인트
#    ① 정적 콘텐츠 교체        : app/site  →  /usr/share/nginx/html
#    ② 환경변수 기반 설정 주입  : app/templates  →  시작 시 실제 설정으로 치환
#    ③ 헬스체크 추가           : /healthz 를 주기적으로 확인
#    ④ 이미지 메타데이터(LABEL) : 이미지의 출처/용도를 이미지 자체에 기록
# ─────────────────────────────────────────────────────────────

# ① 베이스 이미지 : 어떤 반죽으로 시작할지 (항상 맨 처음, 필수)
FROM nginx:1.27-alpine

# ④ 이미지 메타데이터 : docker inspect 로 확인 가능
LABEL org.opencontainers.image.title="cody-web" \
      org.opencontainers.image.description="Codyssey mission 1 custom nginx image" \
      org.opencontainers.image.source="https://github.com/nan-park/cody-e1-1" \
      org.opencontainers.image.authors="nan-park"

# 실행 시점에 docker run -e 로 덮어쓸 수 있는 기본값
ENV APP_ENV=dev \
    NGINX_PORT=8080

# ① 내가 만든 웹페이지를 nginx 의 공개 폴더로 복사
COPY app/site/ /usr/share/nginx/html/

# ② 기본 제공 설정은 80 포트를 쓰므로 제거하고, 환경변수 템플릿으로 대체
RUN rm -f /etc/nginx/conf.d/default.conf
COPY app/templates/default.conf.template /etc/nginx/templates/default.conf.template

# 이 이미지가 쓰는 포트를 문서로 남긴다 (실제 공개는 docker run -p 가 결정)
EXPOSE 8080

# ③ 헬스체크 : "떠 있는지"가 아니라 "응답하는지"를 확인
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:${NGINX_PORT}/healthz || exit 1

# CMD 는 베이스 이미지의 값(nginx -g 'daemon off;')을 그대로 물려받는다.
