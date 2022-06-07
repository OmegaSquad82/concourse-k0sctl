# concourse-k0sctl

It's a container image which instruments [k0sctl][k0sctl], a CLI to manage [k0s][k0sproject] Kubernetes clusters. The image currently is publicly available on Docker Hub as `omegasquad82/k0sctl-handler`. This project aims to provide a simple, configurable [Concourse][concourse-ci] pipeline example, but it is neither production ready nor currently _intended_ to be run in security sensitive settings. It may improve over time. Feedback, ideas and any other contribution welcome.

## Pipeline

![k0sctl pipeline][image-pipeline]

### ping

It will periodically _traceroute_ the cluster's controller and worker node's IPv4 addresses as per the configuration in the `config` git repository.

### init

It initializes the `backup` git repository with an empty commit. An existing `backup` branch will be overwritten on subsequent builds.

### install

This Job calls `k0sctl apply` onto takes configuration from the `config` repository under it's default path `k0sctl.yaml` (configurable). If a non-empty `k0sctl_backup_latest` file exists in the `backup` repository, it will be passed to k0sctl, which will restore the cluster's state if and only if it is a [fresh][k0sctl-restore.go#149l25] installation.

![k0sctl restored the cluster state][image-job-install]

### uninstall

Would destroy the cluster by calling `k0sctl reset`.

### backup

Calls `k0sctl backup` and saves it's output archive in the `backup` git repository.

![k0sctl backup archives][image-git-backups]

## Dockerfile

The image is based on [Alpine Linux 3.16][alpine-3.16] and the [buildx ci][buildx-ci] workflow has been prepared to build it both for `linux/amd64` and `linux/arm64` targets. Currently there is a lack in smoke testing during the build and testing unfortunately done via the pipeline template. Until this has been corrected it still occasionally breaks during tinkering.

### Github inventory

| package          | version |
| ---------------- | ------- |
| [k0sctl][k0sctl] | v0.13.0 |

### Alpine inventory

| [package][alpine-packages] | version >= |
| -------------------------- | ---------- |
| bash                       | 5.1.16-r2  |
| curl                       | 7.83.1-r1  |
| git                        | 2.36.1-r0  |
| grep                       | 2.36.1-r0  |
| mtr                        | 0.95-r1    |

---

[alpine-3.16]: https://alpinelinux.org/posts/Alpine-3.16.0-released.html
[alpine-packages]: https://pkgs.alpinelinux.org/packages
[alpine-releases]: https://alpinelinux.org/releases/
[buildx-ci]: /.github/workflows/buildx-ci.yml
[concourse-ci]: https://concourse-ci.org/
[image-git-backups]: /images/git-backups.png
[image-job-install]: /images/job-install-restoring.png
[image-pipeline]: /images/pipeline.png
[k0sctl]: https://github.com/k0sproject/k0sctl
[k0sctl-restore.go#149l25]: https://github.com/k0sproject/k0sctl/pull/149/commits/6e7c262904ed05b7068e818954a5091d25504065#diff-2cad3981690f3fb1f7b9494273cb87a7b751a5f3f884b9ad0e6a119d60f2f1a2R25
[k0sproject]: https://k0sproject.io/
[markdown]: https://devhints.io/markdown
