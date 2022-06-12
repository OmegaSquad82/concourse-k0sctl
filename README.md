# concourse-k0sctl

It's a container image which instruments [k0sctl][github-k0sctl], a CLI to
manage [k0s][link-k0sproject] Kubernetes clusters. The image currently is
publicly available on Docker Hub as `omegasquad82/k0sctl-handler`. This project
aims to provide a simple, configurable [Concourse][link-concourse] pipeline
example, but it is neither production ready nor currently _intended_ to be run
in security sensitive settings. It may improve over time. Feedback, ideas and
any other contribution is welcome.

## containerimage

The image built with the [Dockerfile][repo-dockerfile] is based on [Alpine Linux
3.16.0][link-alpine-release] and the [buildx ci][repo-ci-buildx] workflow has
been prepared to build it both for `linux/amd64` and `linux/arm64` targets.
Currently there is a lack in smoke testing during the build and testing
unfortunately done via the pipeline template. Until this has been corrected it
still occasionally breaks during tinkering.

## security

Both pipeline and containerimage are being built in my free time and are a fun
project. In contrary to what the above states it is imperative that you never
leak any private key data you handle. This product encrypts it's backup. This
feature cannot be turned off at this point in time. It is required that you
[generate][link-gnupg-keygen] a gpg key pair with the exact same values you're
using as `cluster.name` and `cluster.email`, which will be used to both encrypt
the backup _password_ and sign the _commits_ to the backup git repository.

### inventory

#### Github

| package                 | version |
| ----------------------- | ------- |
| [k0sctl][github-k0sctl] | v0.13.0 |

#### Alpine

| [package][link-alpine-packages] | version >= |
| ------------------------------- | ---------- |
| bash                            | 5.1.16-r2  |
| coreutils                       | 9.1-r0     |
| curl                            | 7.83.1-r1  |
| git                             | 2.36.1-r0  |
| gnupg                           | 2.2.35-r3  |
| grep                            | 2.36.1-r0  |
| mtr                             | 0.95-r1    |
| openssl                         | 1.1.1o-r0  |

#### scripts

##### [common.sh][repo-script-common]

A few functions used either in the image or the pipeline or both.

##### [k0sctl-handler.sh][repo-script-k0sctl-handler]

It is the main glue between the pipeline and the CLI. It has several environment
parameters, listed in the order of appearance:

| Name              | Description                                                                    | Default                    |
| ----------------- | ------------------------------------------------------------------------------ | -------------------------- |
| K0SCTL_CMD_NAME   | The action to perform. `backup`, `install`, `uninstall`, `version`             | version                    |
| DISABLE_TELEMETRY | can be set via the pipeline's `no_telemetry` flag.                             | false                      |
| K0SCTL_SSH_KEY    | the contents of the private key to access the controller and worker nodes.     |
| K0SCTL_SSH_TYPE   | the key's name and type                                                        | id_ed25519                 |
| K0SCTL_DIR_CFG    | relative path to a git repository holding the `k0sctl` configuration           | config                     |
| K0SCTL_CFG_PATH   | relative path below `K0SCTL_DIR_CFG` with the `k0sctl` configuration spec      | k0sctl.yaml                |
| K0SCTL_DIR_LOG    | relative path where `k0sctl`s log file will be placed on finishing the script. | auditlog                   |
| K0SCTL_DIR_BAK    | relative path to place backups into.                                           | backup                     |
| K0SCTL_DIR_RES    | relative path to place restoring backups from.                                 | restore                    |
| K0SCTL_PREFIX_BAK | A prefix to recognize `k0sctl`s dated backup archives from.                    | k0s_backup                 |
| K0SCTL_SUFFIX_LOG | The suffix that will be used to save the final k0scdtl log to.                 | log                        |
| K0SCTL_LOG_PATH   | It's the default path where `k0sctl` saves it's full log into.                 | ~/.cache/k0sctl/k0sctl.log |
| K0SCTL_SUFFIX_BAK | The suffix of the backup archive.                                              | b64                        |

## Pipeline

You'll find it's specification in [pipeline.yml][repo-pipeline].
![k0sctl pipeline][image-pipeline]

### Variables

An example parametrization is in [var-example.yml][repo-pipeline-vars].

| path                      | concourse resource type  | description                                |
| ------------------------- | ------------------------ | ------------------------------------------ |
| email                     | pcfseceng/email-resource | email alerting parameters                  |
| k0sctl.config             | git                      | repository with `k0sctl` configuration     |
| k0sctl.backup             | git                      | repository to backup/restore cluster state |
| k0sctl.cluster.\_key      | string                   | private SSH key                            |
| k0sctl.cluster.mail       | string                   | committer's email address for backups      |
| k0sctl.cluster.name       | string                   | email alert subject preamble               |
| k0sctl.flags.no_telemetry | boolean                  | wether `k0sctl` should call home           |
| timer.ping                | time                     | when to execute traceroutes                |
| timer.backup              | time                     | when to execute backups                    |

### Jobs

#### ping

It will periodically _traceroute_ using `mtr` any valid IPv4 address present in
the files retrieved by `config/*.yaml` glob.

#### init

It initializes the `backup` git repository with an encrypted `secret.gpg` file
that contains a password to safely store the backups. An existing `backup`
branch will be overwritten on subsequent builds.

#### install

This Job calls `k0sctl apply` with configuration from the `config` repository
under it's default path `k0sctl.yaml` (configurable). If a non-empty
`k0sctl_backup_latest` file exists in the `backup` repository, it will be
decrypted with [openssl enc -aes256 -d][link-openssl-enc] and streamed to
k0sctl, which will restore the cluster's state if and only if it is a
[fresh][github-k0sctl-restore.go#149l25] installation.

![k0sctl restored the cluster state][image-job-install]

#### uninstall

Destroys the cluster by calling `k0sctl reset`.

#### backup

Calls `k0sctl backup` and streams it's output archive to [openssl enc -aes256
-e][link-openssl-enc] and the encrypted data is streamed into a time stamped
file, which will be saved in the `backup` git repository. A symlink will be
created to easily access it during the restore operation.

![k0sctl backup archives][image-git-backups]

---

[image-git-backups]: /images/git-backups.png
[image-job-install]: /images/job-install-restoring.png
[image-pipeline]: /images/pipeline.png
[github-k0sctl]: https://github.com/k0sproject/k0sctl
[github-k0sctl-restore.go#149l25]:
  https://github.com/k0sproject/k0sctl/pull/149/commits/6e7c262904ed05b7068e818954a5091d25504065#diff-2cad3981690f3fb1f7b9494273cb87a7b751a5f3f884b9ad0e6a119d60f2f1a2R25
[link-concourse]: https://concourse-ci.org/
[link-k0sproject]: https://k0sproject.io/
[link-alpine-packages]: https://pkgs.alpinelinux.org/packages?name=&branch=v3.16
[link-alpine-release]: https://alpinelinux.org/posts/Alpine-3.16.0-released.html
[link-gnupg-keygen]:
  https://gnupg.org/documentation/manuals/gnupg/OpenPGP-Key-Management.html#OpenPGP-Key-Management
[link-markdown]: https://devhints.io/markdown
[link-openssl-enc]: https://www.openssl.org/docs/man1.1.1/man1/enc.html
[repo-ci-buildx]: /.github/workflows/buildx-ci.yml
[repo-dockerfile]: /Dockerfile
[repo-pipeline]: /ci/pipeline.yml
[repo-pipeline-vars]: /ci/vars-example.yml
[repo-script-common]: /scripts/common.sh
[repo-script-k0sctl-handler]: /scripts/k0sctl-handler.sh
