ARG ADVANCED_THEME_VERSION=0.1.3
ARG ALPINE_VERSION=3.18
ARG CYPRESS_IMAGE_SNAPSHOT_VERSION=8.1.2
ARG CYPRESS_TERMINAL_REPORT_VERSION=5.3.6
ARG CYPRESS_VERSION=13.7.1
ARG FIREFOX_VERSION=117.0.1-1
ARG PYTHON_VERSION=3.11
ARG SEARXNG_VERSION=b21aaa89075b325bd89d2f9f5dc82bbb66855d12

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} as app

ARG SEARXNG_PATH=/usr/local/searxng
ARG SEARXNG_REPO=https://github.com/searxng/searxng.git
ARG SEARXNG_VERSION

RUN apk add --virtual .build-deps \
        build-base \
    && apk add \
        git \
        uwsgi-python3 \
    && git clone "$SEARXNG_REPO" "$SEARXNG_PATH" \
    && cd "$SEARXNG_PATH" \
    && git checkout "$SEARXNG_VERSION" \
    && pip install --upgrade pip \
    && pip install --no-cache -r requirements.txt

ARG ADVANCED_THEME_PATH=${SEARXNG_PATH}/searx/templates/advanced
ARG ADVANCED_THEME_REPO=https://github.com/SatoshiGuacamole/searxng-advanced-theme.git
ARG ADVANCED_THEME_VERSION

RUN git clone "$ADVANCED_THEME_REPO" "$ADVANCED_THEME_PATH" \
    && cd "$ADVANCED_THEME_PATH" \
    && git checkout "$ADVANCED_THEME_VERSION" \
    && rm -rf \
        "${ADVANCED_THEME_PATH}/.git" \
    && apk del .build-deps

COPY --link rootfs /

RUN chown -R nobody \
        "$SEARXNG_PATH" \
        /var/log/uwsgi/ \
    && chmod +x /entrypoint.sh

USER nobody

EXPOSE 1234

ENTRYPOINT ["/entrypoint.sh"]

FROM cypress/included:${CYPRESS_VERSION} as cypress

ARG CYPRESS_IMAGE_SNAPSHOT_VERSION
ARG CYPRESS_TERMINAL_REPORT_VERSION
ARG FIREFOX_VERSION

ARG BUILD_DEPS=" \
    curl \
    jq \
"

RUN npm install -g \
        "@simonsmith/cypress-image-snapshot@${CYPRESS_IMAGE_SNAPSHOT_VERSION}" \
        "cypress-terminal-report@${CYPRESS_TERMINAL_REPORT_VERSION}"

WORKDIR /build/firefox

RUN test -n "$ARCHITECTURE" || case $(uname -m) in \
        aarch64) ARCHITECTURE=arm64; ;; \
        amd64) ARCHITECTURE=amd64; ;; \
        arm64) ARCHITECTURE=arm64; ;; \
        armv8b) ARCHITECTURE=arm64; ;; \
        armv8l) ARCHITECTURE=arm64; ;; \
        x86_64) ARCHITECTURE=amd64; ;; \
        *) echo "Unsupported architecture, exiting..."; exit 1; ;; \
    esac \
    && echo "deb http://deb.debian.org/debian stable main" > /etc/apt/sources.list \
    && echo "deb http://deb.debian.org/debian unstable main" >> /etc/apt/sources.list \
    && apt update \
    && apt install -t stable -y $BUILD_DEPS \
    && FIREFOX_INFO=$(curl -s "https://snapshot.debian.org/mr/binary/firefox/${FIREFOX_VERSION}/binfiles?fileinfo=1" \
        | jq -r '.fileinfo as $fileinfo | .result[] | select(.architecture == "'"$ARCHITECTURE"'") | .hash as $hash | $fileinfo[$hash][0] | $hash + " " + .name') \
    && FIREFOX_HASH="${FIREFOX_INFO%% *}" \
    && FIREFOX_FILE="${FIREFOX_INFO#* }" \
    && curl -sSL "https://snapshot.debian.org/file/${FIREFOX_HASH}" -o "$FIREFOX_FILE" \
    && apt install -y "./${FIREFOX_FILE}"

COPY tests/e2e /tests/e2e

WORKDIR /tests/e2e

RUN npm link \
        @simonsmith/cypress-image-snapshot \
        cypress-terminal-report

ENV CYPRESS_BASE_URL=http://searx:1234

ENTRYPOINT ["cypress"]
