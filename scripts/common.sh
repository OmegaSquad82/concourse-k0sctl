# shellcheck shell=bash
[[ "$DEBUG" ]] && set -x
# https://devhints.io/bash
set -euo pipefail # strict
IFS=$'\n\t'

traperr() {
	echo "ERROR: ${BASH_SOURCE[1]} at about ${BASH_LINENO[0]}"
}

case $(readlink /proc/$$/exe) in
/bin/bash)
	set -o errtrace
	trap traperr ERR
	;;
esac

function assertDir() {
	local dir="${1:?'Please specify a directory!'}"
	if [ ! -d "$dir" ]; then
		echo "$dir not found"
		exit 2 # ENOENT No such file or directory
	fi
}

function assertFile() {
	local file="${1:?'Please specify a file!'}"
	if [ ! -s "$file" ]; then
		echo "$file not found"
		exit 2 # ENOENT No such file or directory
	fi
}

function printHeading() {
	local padlimit='100'
	local text="$*"
	local pad
	# shellcheck disable=SC2183
	pad="$(printf '%*s' "$padlimit")"
	pad="${pad// /=}"
	printf '%s' "$text "
	printf '%*.*s\n' 0 $((padlimit - "${#text}")) "$pad"
}

# shellcheck disable=SC2068
function runCMD() {
	echo 'λ' $@
	$@
}

function prepareSSH() {
	printHeading 'preparing ssh'
	local privateKeyData="${1:-"${SSH_KEY:?'Need private key!'}"}"
	local privateKeyName="${2:-id_ed25519}"
	mkdir -p ~/.ssh
	echo "$privateKeyData" >~/.ssh/"$privateKeyName"
	chmod 0400 ~/.ssh/"$privateKeyName"
}

function prepareGIT() {
	printHeading 'preparing git'
	local repo_path="${1:?'Please specify a git repository!'}"
	local git_mail="${2:-"${MAILBOX:?'Please specify your mail address!'}"}"
	local git_name="${3:-"${GITNAME:-automaton @ http://concourse-ci.org}"}"
	cd "$repo_path" || (echo "$repo_path does not exist" && exit 2) # ENOENT
	runCMD git config --global --add safe.directory "$(pwd)"
	runCMD git config --global user.email "$git_mail"
	runCMD git config --global user.name "$git_name"
}

function cloneGitRepo() {
	printHeading 'cloning git repository'
	local clonerepo="${1:?'Please specify source repository!'}"
	local dest_repo="${2:?'Please specify target repository!'}"
	local user_name="${3:-"${HOME##*/}"}" # should be root
	runCMD chown -R "$user_name" "$dest_repo"
	runCMD git clone "$clonerepo" "$dest_repo"
}

function initBranch() {
	printHeading 'preparing ophaned git branch'
	local branchName="${1:?'Please specify a branch name!'}"
	runCMD git switch --orphan "$branchName"
	runCMD git rm --cached -r . || true
	runCMD git clean -df .??* . || true
	runCMD git commit --allow-empty -m "init"
}

function commitAllFiles() {
	printHeading 'committing to repository'
	local message="${1:?'Please specify a commit message!'}"
	runCMD git add .
	runCMD git commit -m "$message"
}

function tracerouteSSH() {
	printHeading 'tracing route to ssh port of nodes'
	local sourceFile="${1:?'Please specify a source file!'}"
	local portNumber="${2:-22}"
	local searchPatt='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
	mkfifo addresses
	grep -E -o "$searchPatt" "$sourceFile" >addresses &
	while IFS= read -r ipv4; do
		runCMD mtr --report-wide --no-dns --tcp --port "$portNumber" "$ipv4"
	done <addresses
	rm addresses
}
