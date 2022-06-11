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
    assertFile "$RES/secret.gpg"
    prepareGPG "$K0SCTL_GPG_KEY"
    password="pass:$(gpg decrypt "$RES/secret.gpg")"
    openssl enc -aes256 -in "$RES/${latest}" -out - -pass "$password" -d -a -pbkdf2 | k0sctl apply --config "$CFG" --restore-from -
  else
    runCMD k0sctl apply --config "$CFG"
  fi
  ;;
uninstall)
  runCMD k0sctl reset --config "$CFG" --force
  ;;
backup)
  assertDir "$BAK"
  assertFile "$RES/secret.gpg"
  prepareGPG "$K0SCTL_GPG_KEY"
  password="pass:$(gpg decrypt "$RES/secret.gpg")"
  archive="${K0SCTL_PREFIX_BAK}_${started}_${K0SCTL_SUFFIX_BAK:-b64}"
  runCMD k0sctl backup --config "$CFG" --save-path - | openssl enc -aes256 -in - -out "$archive" -pass "$password" -e -a -pbkdf2
  runCMD ln -s "$archive" -T "$latest"
  runCMD mv -f "$archive" "$latest" -t "$BAK"
  echo "$archive saved as $latest" >"$BAK/.message"
  ;;
*)
  exit 1 # EPERM Operation not permitted
  ;;
esac
