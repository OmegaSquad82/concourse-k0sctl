#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

Tools=(
	chmod
	curl
	git
	k0sctl
	ln
	mtr
	mv
)
echo '
checking required runtime tools are somewhere in PATH'
for tool in "${Tools[@]}"; do
	command -V "$tool"
done
