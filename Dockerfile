# syntax=docker/dockerfile:1.4
# https://devhints.io/dockerfile
FROM alpine:3.16.2 as release

ARG TARGETPLATFORM

# renovate: datasource=repology depName=alpine_3_16/bash versioning=loose
ENV BASH_VERSION="5.1.16-r2"

# renovate: datasource=repology depName=alpine_3_16/coreutils versioning=loose
ENV COREUTILS_VERSION="9.1-r0"

# renovate: datasource=repology depName=alpine_3_16/curl versioning=loose
ENV CURL_VERSION="7.83.1-r4"

# renovate: datasource=repology depName=alpine_3_16/git versioning=loose
ENV GIT_VERSION="2.36.3-r0"

# renovate: datasource=repology depName=alpine_3_16/gnupg versioning=loose
ENV GNUPG_VERSION="2.2.35-r4"

# renovate: datasource=repology depName=alpine_3_16/grep versioning=loose
ENV GREP_VERSION="3.7-r0"

# renovate: datasource=repology depName=alpine_3_16/mtr versioning=loose
ENV MTR_VERSION="0.95-r1"

# renovate: datasource=repology depName=alpine_3_16/openssl versioning=loose
ENV OPENSSL_VERSION="1.1.1q-r0"

# Releases: https://github.com/k0sproject/k0sctl/releases/latest
ENV K0SCTL_VER="v0.14.0"

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]
RUN apk add --no-cache \
        bash="${BASH_VERSION}" \
        coreutils="${COREUTILS_VERSION}" \
        curl="${CURL_VERSION}" \
        git="${GIT_VERSION}" \
        gnupg="${GNUPG_VERSION}" \
        grep="${GREP_VERSION}" \
        mtr="${MTR_VERSION}" \
        openssl="${OPENSSL_VERSION}" \
        && \
    case "${TARGETPLATFORM:-linux/amd64}" in \
    "linux/amd64") K0SCTL_BIN="linux-x64"   K0SCTL_SHA256="7fbe42adb4f775e2f87b4dc46ed97aa7d4c0ce8b9135e799a122a4c2fbec2b59" ;; \
    "linux/arm64") K0SCTL_BIN="linux-arm64" K0SCTL_SHA256="8fc33a124fd7fb85ebde92ec5393b0d22eef753b56a08aac3e350b8a85ff09a2" ;; \
    *) echo "platform $TARGETPLATFORM not supported" && exit 1 ;; esac && \
    curl -SL "https://github.com/k0sproject/k0sctl/releases/download/${K0SCTL_VER}/k0sctl-${K0SCTL_BIN}" -o /usr/bin/k0sctl && \
    echo "${K0SCTL_SHA256} */usr/bin/k0sctl" | sha256sum -c && chmod 0555 /usr/bin/k0sctl && \
    apk stats

WORKDIR /root/
COPY scripts/ /usr/local/bin
CMD ["k0sctl-handler.sh"]

FROM release as testing
COPY tests/ /
RUN /installed.sh && k0sctl version

FROM release
