# syntax=docker/dockerfile:1.20
# https://devhints.io/dockerfile
FROM alpine:3.23.2 AS release

ARG TARGETPLATFORM

# renovate: datasource=repology depName=alpine_3_23/bash versioning=loose
ENV BASH_VERSION="5.3.3-r1"

# renovate: datasource=repology depName=alpine_3_23/coreutils versioning=loose
ENV COREUTILS_VERSION="9.8-r1"

# renovate: datasource=repology depName=alpine_3_23/curl versioning=loose
ENV CURL_VERSION="8.17.0-r1"

# renovate: datasource=repology depName=alpine_3_23/git versioning=loose
ENV GIT_VERSION="2.52.0-r0"

# renovate: datasource=repology depName=alpine_3_23/gnupg versioning=loose
ENV GNUPG_VERSION="2.4.9-r0"

# renovate: datasource=repology depName=alpine_3_23/grep versioning=loose
ENV GREP_VERSION="3.12-r0"

# renovate: datasource=repology depName=alpine_3_23/k0sctl versioning=loose
ENV K0SCTL_VERSION="0.25.1-r5"

# renovate: datasource=repology depName=alpine_3_23/mtr versioning=loose
ENV MTR_VERSION="0.96-r0"

# renovate: datasource=repology depName=alpine_3_23/openssl versioning=loose
ENV OPENSSL_VERSION="3.5.4-r0"

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
