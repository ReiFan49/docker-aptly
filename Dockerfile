ARG GOLANG_VERSION="1.22"

FROM golang:${GOLANG_VERSION}-alpine AS golang-build
ARG BRANCH="master"
ARG REPOSITORY="https://github.com/aptly-dev/aptly"
ARG OUTPUT_NAME="aptly"

RUN apk add --update --no-cache build-base upx git
WORKDIR /app
RUN \
  echo "BRANCH: ${BRANCH}"; echo "REPO:   ${REPOSITORY?Repository name is required.}"; \
  mkdir src build && \
  git config --global advice.detachedHead false && \
  git clone -b ${BRANCH} "${REPOSITORY}" src && \
  cd src && \
  make modules

RUN \
  cd src && \
  env GOOS=linux CGO_ENABLED=0 go build \
    -ldflags "-s -w -extldflags '-static c'" \
    -o /app/build/${OUTPUT_NAME} && \
  upx -9 -q /app/build/${OUTPUT_NAME} >/dev/null 2>/dev/null && \
  env HOME=/app /app/build/${OUTPUT_NAME} config show && \
    sed -i -e 's|/app/\.aptly|/app/data|g' /app/.aptly.conf && \
  apk del -q build-base git

FROM scratch AS final
ARG OUTPUT_NAME="aptly"
WORKDIR /app
ENV HOME=/app
COPY --from=reifan49/supervisord:0.7.3 /usr/bin/supervisord /usr/bin/supervisord
COPY --from=golang-build /app/build/${OUTPUT_NAME} /usr/local/bin/${OUTPUT_NAME}
COPY --from=golang-build /app/.aptly.conf /etc/aptly.conf
COPY supervisord.conf /etc/supervisord.conf

ENTRYPOINT ["supervisord"]
