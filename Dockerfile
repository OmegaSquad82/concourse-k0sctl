# syntax=docker/dockerfile:1.3
# https://devhints.io/dockerfile
FROM alpine:3.16 as release

ARG TARGETPLATFORM
ENV K0SCTL_VER="v0.13.0"

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]
# hadolint ignore=DL3018
RUN case $TARGETPLATFORM in \
    "linux/amd64") K0SCTL_BIN="linux-x64"   K0SCTL_SHA256="0beb8fb539c1f1e796972ed10d13bf5c3d5bb06d3c99a1b3f9a3f23183eaaaff" ;; \
    "linux/arm64") K0SCTL_BIN="linux-arm64" K0SCTL_SHA256="7184ebd3e414caca2361a9c42036c1e6e598626ee2ec3443afed6ed901e3889e" ;; \
    *) echo "platform $TARGETPLATFORM not supported" && exit 1 ;; esac && \
    curl -SL "https://github.com/k0sproject/k0sctl/releases/download/${K0SCTL_VER}/k0sctl-${K0SCTL_BIN}" -o /usr/bin/k0sctl && \
    echo "${K0SCTL_SHA256} */usr/bin/k0sctl" | sha256sum -c && chmod 0555 /usr/bin/k0sctl && \
    apk add --no-cache \
        bash \
        curl \
        git \
        grep \
        mtr \
        && \
    apk stats

WORKDIR /root/
COPY scripts/ /usr/local/bin
CMD ["k0sctl-handler.sh"]

FROM release as testing
COPY tests/ /
RUN /installed.sh && k0sctl version

FROM release
