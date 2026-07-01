# syntax=docker/dockerfile:1.24
# https://devhints.io/dockerfile
FROM alpine:3.24.1 AS release

ARG TARGETPLATFORM

# renovate: datasource=repology depName=alpine_3_24/bash versioning=loose
ENV BASH_VERSION="5.3.9-r1"

# renovate: datasource=repology depName=alpine_3_24/coreutils versioning=loose
ENV COREUTILS_VERSION="9.8-r1"

# renovate: datasource=repology depName=alpine_3_24/curl versioning=loose
ENV CURL_VERSION="8.19.0-r0"

# renovate: datasource=repology depName=alpine_3_24/git versioning=loose
ENV GIT_VERSION="2.52.0-r0"

# renovate: datasource=repology depName=alpine_3_24/gnupg versioning=loose
ENV GNUPG_VERSION="2.4.9-r1"

# renovate: datasource=repology depName=alpine_3_24/grep versioning=loose
ENV GREP_VERSION="3.12-r0"

# renovate: datasource=repology depName=alpine_3_24/k0sctl versioning=loose
ENV K0SCTL_VERSION="0.25.1-r9"

# renovate: datasource=repology depName=alpine_3_24/mtr versioning=loose
ENV MTR_VERSION="0.96-r2"

# renovate: datasource=repology depName=alpine_3_24/openssl versioning=loose
ENV OPENSSL_VERSION="3.5.7-r0"

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

FROM release AS testing
COPY tests/ /
RUN /installed.sh && k0sctl version

FROM release
