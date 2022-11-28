# syntax=docker/dockerfile:1.4
# https://devhints.io/dockerfile
FROM alpine:3.17.0 as release

ARG TARGETPLATFORM

# renovate: datasource=repology depName=alpine_3_17/bash versioning=loose
ENV BASH_VERSION="5.1.16-r2"

# renovate: datasource=repology depName=alpine_3_17/coreutils versioning=loose
ENV COREUTILS_VERSION="9.1-r0"

# renovate: datasource=repology depName=alpine_3_17/curl versioning=loose
ENV CURL_VERSION="7.83.1-r4"

# renovate: datasource=repology depName=alpine_3_17/git versioning=loose
ENV GIT_VERSION="2.36.3-r0"

# renovate: datasource=repology depName=alpine_3_17/gnupg versioning=loose
ENV GNUPG_VERSION="2.2.40-r0"

# renovate: datasource=repology depName=alpine_3_17/grep versioning=loose
ENV GREP_VERSION="3.7-r0"

# renovate: datasource=repology depName=alpine_3_17/k0sctl versioning=loose
ENV K0SCTL_VERSION="0.14.0-r2"

# renovate: datasource=repology depName=alpine_3_17/mtr versioning=loose
ENV MTR_VERSION="0.95-r1"

# renovate: datasource=repology depName=alpine_3_17/openssl versioning=loose
ENV OPENSSL_VERSION="1.1.1s-r0"

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]
RUN apk add --no-cache \
        bash="${BASH_VERSION}" \
        coreutils="${COREUTILS_VERSION}" \
        curl="${CURL_VERSION}" \
        git="${GIT_VERSION}" \
        gnupg="${GNUPG_VERSION}" \
        grep="${GREP_VERSION}" \
        k0sctl="${K0SCTL_VERSION}" \
        mtr="${MTR_VERSION}" \
        openssl="${OPENSSL_VERSION}" \
        && \
    apk stats

WORKDIR /root/
COPY scripts/ /usr/local/bin
CMD ["k0sctl-handler.sh"]

FROM release as testing
COPY tests/ /
RUN /installed.sh && k0sctl version

FROM release
