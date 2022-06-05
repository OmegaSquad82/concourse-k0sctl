#!/usr/bin/env bash
# shellcheck source=common.sh
source "${0%/*}"/common.sh
prepareSSH "$SSH_KEY"

printHeading 'preparing environment'
env | grep K0SCTL # show the vars that be
CFG="$(pwd)/${K0SCTL_DIR_CFG:?}/${K0SCTL_CFG_PATH:?}"
checkFile "$CFG"

LOG="$(pwd)/${K0SCTL_DIR_LOG:?}"
checkDir "$LOG"

BAK="$(pwd)/${K0SCTL_DIR_BAK:?}"
RES="$(pwd)/${K0SCTL_DIR_RES:?}"

printHeading 'managing cluster'
cd "$HOME" || exit 2 # ENOENT
started="$(date +%F-%H-%M-%S)"
case "${K0SCTL_CMD_NAME:?}" in
install)
	# shellcheck disable=SC2086
	runCMD k0sctl apply --config "$CFG" $K0SCTL_CMD_ARGS
	;;
uninstall)
	# shellcheck disable=SC2086
	runCMD k0sctl reset --config "$CFG" --force $K0SCTL_CMD_ARGS
	;;
backup)
	checkDir "$BAK"
	checkDir "$RES"
	# shellcheck disable=SC2086
	runCMD k0sctl backup --config "$CFG" $K0SCTL_CMD_ARGS
	;;
restore)
	checkDir "$RES"
	archive="$RES/${PREFIX_BAK}_latest"
	checkFile "$archive"
	# shellcheck disable=SC2086
	runCMD k0sctl apply --config "$CFG" --restore-from="${archive}" $K0SCTL_CMD_ARGS
	;;
*)
	exit 1 # EPERM Operation not permitted
	;;
esac

printHeading 'saving logfile'
runCMD sudo mv ~/.cache/k0sctl/k0sctl.log "$LOG/$started-$K0SCTL_CMD_NAME.$SUFFIX_LOG"

case "$K0SCTL_CMD_NAME" in
backup)
	USR="${HOME##*/}"
	printHeading 'saving backup archive'
	cloneGitRepo "$RES" "$BAK" "$USR"
	prepareGIT "$BAK" "$MAILBOX"
	runCMD git checkout "${K0SCTL_DIR_BAK}"
	latest="${PREFIX_BAK}_latest"
	mapfile -t archives < <(find "$HOME" -maxdepth 1 -name "${PREFIX_BAK}*${SUFFIX_BAK}")
	for archiveHome in "${archives[@]}"; do
		checkFile "$archiveHome"
		archive="${archiveHome##*/}"
		runCMD mv -n "$archiveHome" -t "$BAK"
		runCMD ln -sb "$archive" -T "$latest"
		commitAllFiles "$archive saved as $latest"
	done
	;;
esac
