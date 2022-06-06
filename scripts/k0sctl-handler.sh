#!/usr/bin/env bash
# shellcheck source=common.sh
source "${0%/*}"/common.sh

printHeading 'k0sctl handler'
case "${K0SCTL_CMD_NAME-version}" in
version)
	runCMD k0sctl version
	exit 0 # buildx test
	;;
esac

printHeading 'preparing environment'
case "${DISABLE_TELEMETRY:-false}" in
true)
	;;
*) DISABLE_TELEMETRY=false
	;;
esac
env | grep -E '(K0SCTL|TELEMETRY)'
prepareSSH "$SSH_KEY" "${SSH_TYPE:-id_ed25519}"

CFG="$(pwd)/${K0SCTL_DIR_CFG:-config}/${K0SCTL_CFG_PATH:-k0sctl.yaml}"
assertFile "$CFG"

LOG="$(pwd)/${K0SCTL_DIR_LOG:-auditlog}"
assertDir "$LOG"

BAK="$(pwd)/${K0SCTL_DIR_BAK:-backup}"
RES="$(pwd)/${K0SCTL_DIR_RES:-restore}"
latest="${PREFIX_BAK:-k0s_backup}_latest"

printHeading 'managing cluster'
cd "$HOME" || exit 2 # ENOENT
started="$(date +%F-%H-%M-%S)"
case "$K0SCTL_CMD_NAME" in
install)
	# shellcheck disable=SC2086
	runCMD k0sctl apply --config "$CFG" ${K0SCTL_CMD_ARGS:-}
	;;
uninstall)
	# shellcheck disable=SC2086
	runCMD k0sctl reset --config "$CFG" --force $K0SCTL_CMD_ARGS
	;;
backup)
	assertDir "$BAK"
	assertDir "$RES"
	# shellcheck disable=SC2086
	runCMD k0sctl backup --config "$CFG" $K0SCTL_CMD_ARGS
	;;
restore)
	assertDir "$RES"
	assertFile "$RES/${latest}"
	# shellcheck disable=SC2086
	runCMD k0sctl apply --config "$CFG" --restore-from="$RES/${latest}" $K0SCTL_CMD_ARGS
	;;
*)
	exit 1 # EPERM Operation not permitted
	;;
esac

printHeading 'saving logfile'
runCMD mv ~/.cache/k0sctl/k0sctl.log "$LOG/$started-$K0SCTL_CMD_NAME.${SUFFIX_LOG:-log}"

case "$K0SCTL_CMD_NAME" in
backup)
	USR="${HOME##*/}"
	printHeading 'saving backup archive'
	cloneGitRepo "$RES" "$BAK" "$USR"
	prepareGIT "$BAK" "$MAILBOX"
	runCMD git checkout "${K0SCTL_DIR_BAK}"
	mapfile -t archives < <(find "$HOME" -maxdepth 1 -name "${PREFIX_BAK}*${SUFFIX_BAK:-tar.gz}")
	for archiveHome in "${archives[@]}"; do
		assertFile "$archiveHome"
		archive="${archiveHome##*/}"
		runCMD mv -n "$archiveHome" -t "$BAK"
		runCMD ln -sb "$archive" -T "$latest"
		commitAllFiles "$archive saved as $latest"
	done
	;;
esac
