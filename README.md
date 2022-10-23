# concourse-k0sctl

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/3d2c20609b6a4720b107c7fd31f8c20e)](https://www.codacy.com/gh/OmegaSquad82/concourse-k0sctl/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=OmegaSquad82/concourse-k0sctl&amp;utm_campaign=Badge_Grade)

It's a container image which instruments [k0sctl][github-k0sctl], a CLI to
manage [k0s][link-k0sproject] Kubernetes clusters. The image currently is
publicly available on Docker Hub as `omegasquad82/k0sctl-handler`. This project
aims to provide a simple, configurable [Concourse][link-concourse] pipeline
example, but it is neither production ready nor currently _intended_ to be run
in security sensitive settings. It may improve over time. Feedback, ideas and
any other contribution is welcome.

## containerimage

The image built with the [Dockerfile][repo-dockerfile] is based on [Alpine Linux
3.16.x][link-alpine-release] and the [buildx ci][repo-ci-buildx] workflow has
been prepared to build it both for `linux/amd64` and `linux/arm64` targets.
Currently there is a lack in smoke testing during the build and testing
unfortunately done via the pipeline template. Until this has been corrected it
still occasionally breaks during tinkering.

## security

Both pipeline and containerimage are being built in my free time and are a fun
project. In contrary to what the above states it is imperative that you never
leak any private key data you handle. This product encrypts the files created
with `k0sctl backup`. This feature cannot be turned off at this point in time.

It is required that you [generate][link-gnupg-keygen], and provide via pipeline
_vars_, a `cluster.gpg_pair` with the exact same Name and Mail, but no Comment,
values you're providing to the pipeline as `cluster.name` and `cluster.email`.

These values will be used to both en- and later decrypt the backup _password_ as
well as sign all _commits_ to the backup git repository during relevant Jobs.
Please review this [document][link-github-gpg] for more information about commit
signature verification.

## praise

My gratitude to @rstacruz as I'm heavily relying on their cheat sheets for both
[bash][link-bash] and [markdown][link-markdown] during my day to day work.

### inventory

#### Alpine

| [package][link-alpine-packages] | version =  |
| ------------------------------- | ---------- |
| bash                            | 5.1.16-r2  |
| coreutils                       | 9.1-r0     |
| curl                            | 7.83.1-r3  |
| git                             | 2.36.3-r0  |
| gnupg                           | 2.2.35-r4  |
| grep                            | 3.7-r0     |
| mtr                             | 0.95-r1    |
| openssl                         | 1.1.1q-r0  |

#### Github

| package                 | version |
| ----------------------- | ------- |
| [k0sctl][github-k0sctl] | v0.14.0 |

#### scripts

##### [common.sh][repo-script-common]

A few functions used either in the image or the pipeline or both.

##### [k0sctl-handler.sh][repo-script-k0sctl-handler]

It is the main glue between the pipeline and the CLI. It has several environment
parameters, listed in the order of appearance:

| Name              | Description                | Default                    |
| ----------------- | -------------------------- | -------------------------- |
| K0SCTL_CMD_NAME   | The action to perform.     | version                    |
| DISABLE_TELEMETRY | Pipeline's `no_telemetry`  | false                      |
| K0SCTL_SSH_KEY    | private SSH key content    |                            |
| K0SCTL_SSH_TYPE   | the key's file name        | id_ed25519                 |
| K0SCTL_CFG_PATH   | to `k0sctl` config spec    | config/k0sctl.yaml         |
| K0SCTL_DIR_LOG    | to store `k0sctl`'s log    | auditlog                   |
| K0SCTL_DIR_BAK    | to place backups into.     | backup                     |
| K0SCTL_DIR_RES    | from where to restore      | restore                    |
| K0SCTL_GPG_KEY    | to decrypt backup password |                            |
| K0SCTL_ENC_CIPHER | openssl cipher for backups | chacha20                   |
| K0SCTL_PREFIX_BAK | Prefix of backup archives  | k0s_backup                 |
| K0SCTL_SUFFIX_LOG | Final logfile's suffix     | log                        |
| K0SCTL_LOG_PATH   | `k0sctl` default log path  | ~/.cache/k0sctl/k0sctl.log |
| K0SCTL_SUFFIX_BAK | Suffix of backup archives  | tar.gz                     |

## Pipeline

You'll find it's specification in [pipeline.yml][repo-pipeline].
![k0sctl pipeline][image-pipeline]

### Variables

An example parametrization is in [var-example.yml][repo-pipeline-vars].

| path         | concourse resource type  | description                 |
| ------------ | ------------------------ | --------------------------- |
| email        | pcfseceng/email-resource | email alerting parameters   |
| timer.ping   | time                     | when to execute traceroutes |
| timer.backup | time                     | when to execute backups     |

#### k0sctl

Below the `k0sctl` parameter structure you'll find:

| path               | concourse type | description                           |
| ------------------ | -------------- | ------------------------------------- |
| config             | git            | place to fetch `k0sctl` configuration |
| backup             | git            | to backup/restore the cluster state   |
| cluster.\_key      | string         | private SSH key                       |
| cluster.gpg_pair   | string         | private GPG key                       |
| cluster.mail       | string         | committer's email address for backups |
| cluster.name       | string         | email alert subject preamble          |
| flags.no_telemetry | boolean        | wether `k0sctl` should call home      |

### Jobs

#### ping

It will periodically _traceroute_ using `mtr` any valid IPv4 address present in
the files retrieved by `config/*.yaml` glob.

#### init

It initializes the `backup` git repository with an encrypted `secret.gpg` file
that contains a password to safely store the backups. An existing `backup`
branch will be overwritten on subsequent builds.

![the init Job created a branch with an encrypted password][image-job-init]

#### install

This Job calls `k0sctl apply` with configuration from the `config` repository
under it's default path `k0sctl.yaml` (configurable). If a non-empty
`k0sctl_backup_latest` file exists in the `backup` repository, it will be
decrypted with [openssl enc][link-openssl-enc] handed over to k0sctl, which will
restore the cluster's state if and only if it is a [new][github-k0sctl-restore]
installation.

![k0sctl restored the cluster state][image-job-install]

#### uninstall

Destroys the cluster by calling `k0sctl reset`.

#### backup

Calls `k0sctl backup` and encrypts it's output archive with [openssl
enc][link-openssl-enc] and the encrypted file will be saved in the `backup` git
repository. A symlink will be created to easily access it during the restore
operation.

![k0sctl backup archives][image-git-backups]

---

[image-git-backups]: images/git-backups.png
[image-job-init]: images/git-init.png
[image-job-install]: images/job-install-restoring.png
[image-pipeline]: images/pipeline.png
[github-k0sctl]: https://github.com/k0sproject/k0sctl
[github-k0sctl-restore]:
  https://github.com/k0sproject/k0sctl/pull/149/commits/6e7c262904ed05b7068e818954a5091d25504065#diff-2cad3981690f3fb1f7b9494273cb87a7b751a5f3f884b9ad0e6a119d60f2f1a2R25
[link-bash]: https://devhints.io/bash
[link-concourse]: https://concourse-ci.org/
[link-k0sproject]: https://k0sproject.io/
[link-alpine-packages]: https://pkgs.alpinelinux.org/packages?name=&branch=v3.16
[link-alpine-release]: https://alpinelinux.org/releases/
[link-github-gpg]:
  https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#gpg-commit-signature-verification
[link-gnupg-keygen]:
  https://gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html#OpenPGP-Key-Management
[link-markdown]: https://devhints.io/markdown
[link-openssl-enc]: https://www.openssl.org/docs/man1.1.1/man1/enc.html
[repo-ci-buildx]: .github/workflows/buildx-ci.yml
[repo-dockerfile]: Dockerfile
[repo-pipeline]: ci/pipeline.yml
[repo-pipeline-vars]: ci/vars-example.yml
[repo-script-common]: scripts/common.sh
[repo-script-k0sctl-handler]: scripts/k0sctl-handler.sh
