# syntax=docker/dockerfile:1.16
# https://devhints.io/dockerfile
FROM alpine:3.22.0 AS release

ARG TARGETPLATFORM

# renovate: datasource=repology depName=alpine_3_22/bash versioning=loose
ENV BASH_VERSION="5.2.37-r0"

# renovate: datasource=repology depName=alpine_3_22/coreutils versioning=loose
ENV COREUTILS_VERSION="9.7-r1"

# renovate: datasource=repology depName=alpine_3_22/curl versioning=loose
ENV CURL_VERSION="8.14.0-r2"

# renovate: datasource=repology depName=alpine_3_22/git versioning=loose
ENV GIT_VERSION="2.47.2-r0"

# renovate: datasource=repology depName=alpine_3_22/gnupg versioning=loose
ENV GNUPG_VERSION="2.4.7-r0"

# renovate: datasource=repology depName=alpine_3_22/grep versioning=loose
ENV GREP_VERSION="3.11-r0"

# renovate: datasource=repology depName=alpine_3_22/k0sctl versioning=loose
ENV K0SCTL_VERSION="0.19.4-r5"

# renovate: datasource=repology depName=alpine_3_22/mtr versioning=loose
ENV MTR_VERSION="0.95-r2"

# renovate: datasource=repology depName=alpine_3_22/openssl versioning=loose
ENV OPENSSL_VERSION="3.3.3-r0"

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
