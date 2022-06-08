#!/usr/bin/env bash
# shellcheck source=./common.sh
source "${0%/*}"/common.sh

printHeading 'k0sctl handler'
case "${K0SCTL_CMD_NAME:-version}" in
version)
	runCMD k0sctl version
	exit 0 # buildx test
	;;
esac

printHeading 'preparing environment'
case "${DISABLE_TELEMETRY:-false}" in
true) ;;
*)
	DISABLE_TELEMETRY=false
	;;
esac
env | grep -E '(K0SCTL|TELEMETRY)' | grep -v 'SSH'
prepareSSH "$K0SCTL_SSH_KEY" "${K0SCTL_SSH_TYPE:-id_ed25519}"

CFG="$(pwd)/${K0SCTL_DIR_CFG:-config}/${K0SCTL_CFG_PATH:-k0sctl.yaml}"
assertFile "$CFG"

LOG="$(pwd)/${K0SCTL_DIR_LOG:-auditlog}"
assertDir "$LOG"

BAK="$(pwd)/${K0SCTL_DIR_BAK:=backup}"
RES="$(pwd)/${K0SCTL_DIR_RES:-restore}"
latest="${K0SCTL_PREFIX_BAK:=k0s_backup}_latest"

cd "$HOME" || exit 2 # ENOENT
started="$(date +%F-%H-%M-%S)"
function finish() {
	local logfile="$LOG/$started-$K0SCTL_CMD_NAME.${K0SCTL_SUFFIX_LOG:-log}"
	if [ -s "${K0SCTL_LOG_PATH:="$HOME/.cache/k0sctl/k0sctl.log"}" ]; then
		printHeading 'saving logfile'
		runCMD mv "$K0SCTL_LOG_PATH" "$logfile"
	fi
}
trap finish EXIT

printHeading 'managing cluster'
case "$K0SCTL_CMD_NAME" in
install)
	if [ -d "$RES" ] && [ -s "$RES/${latest}" ]; then
		# shellcheck disable=SC2086
		runCMD k0sctl apply --config "$CFG" --restore-from="$RES/${latest}" ${K0SCTL_CMD_ARGS:-}
	else
		# shellcheck disable=SC2086
		runCMD k0sctl apply --config "$CFG" ${K0SCTL_CMD_ARGS:-}
	fi
	;;
uninstall)
	# shellcheck disable=SC2086
	runCMD k0sctl reset --config "$CFG" --force ${K0SCTL_CMD_ARGS:-}
	;;
backup)
	assertDir "$BAK"
	assertDir "$RES"
	# shellcheck disable=SC2086
	runCMD k0sctl backup --config "$CFG" ${K0SCTL_CMD_ARGS:-}
	printHeading 'saving backup archive'
	cd "$BAK" || (echo "$BAK does not exist" && exit 2) # ENOENT
	mapfile -t archives < <(find "$HOME" -maxdepth 1 -name "${K0SCTL_PREFIX_BAK}*${K0SCTL_SUFFIX_BAK:-tar.gz}")
	for archiveHome in "${archives[@]}"; do
		assertFile "$archiveHome"
		archive="${archiveHome##*/}"
		runCMD mv -n "$archiveHome" -t "$BAK"
		runCMD ln -sb "$archive" -T "$latest"
	done
	;;
*)
	exit 1 # EPERM Operation not permitted
	;;
esac
