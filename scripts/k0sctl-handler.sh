#!/usr/bin/env bash
# shellcheck source=scripts/common.sh
source "${0%/*}"/common.sh

printHeading 'k0sctl handler'
case "${K0SCTL_CMD_NAME:-version}" in
version)
  runCMD k0sctl version
  exit 0 # buildx test
  ;;
esac

printFunction 'preparing environment'
case "${DISABLE_TELEMETRY:-false}" in
true) ;;
*)
  DISABLE_TELEMETRY=false
  ;;
esac
env | grep -E '(K0SCTL|TELEMETRY)' | grep -Ev '(KEY|SSH)'
prepareSSH "$K0SCTL_SSH_KEY" "${K0SCTL_SSH_TYPE:-id_ed25519}"

CFG="$(pwd)/${K0SCTL_CFG_PATH:-config/k0sctl.yaml}"
assertFile "$CFG"

LOG="$(pwd)/${K0SCTL_DIR_LOG:-auditlog}"
assertDir "$LOG"

case "${K0SCTL_CMD_NAME}" in
install | backup)
  BAK="$(pwd)/${K0SCTL_DIR_BAK:=backup}"
  RES="$(pwd)/${K0SCTL_DIR_RES:-restore}"
  assertFile "$RES/secret.gpg"
  prepareGPG "$K0SCTL_GPG_KEY"
  printFunction "decrypting restore/secret.gpg"
  password="pass:$(gpg --decrypt "$RES/secret.gpg")"
  cipher="${K0SCTL_ENC_CIPHER:-chacha20}"
  latest="${K0SCTL_PREFIX_BAK:=k0s_backup}_latest"
  ;;
esac

started="$(date +%F-%H-%M-%S)"
function finish() {
  local logfile="$LOG/$started-$K0SCTL_CMD_NAME.${K0SCTL_SUFFIX_LOG:-log}"
  if [ -s "${K0SCTL_LOG_PATH:="$HOME/.cache/k0sctl/k0sctl.log"}" ]; then
    printFunction 'saving logfile'
    runCMD mv "$K0SCTL_LOG_PATH" "$logfile"
  fi
}
trap finish EXIT

printFunction 'managing cluster'
case "$K0SCTL_CMD_NAME" in
install)
  if [ -d "$RES" ] && [ -s "$RES/${latest}" ]; then
    printFunction "openssl $cipher -in $RES/${latest}"
    openssl "$cipher" -in "$RES/${latest}" -out "${latest}" -pass "$password" -d -a -pbkdf2
    runCMD k0sctl apply --config "$CFG" --restore-from "${latest}"
  else
    runCMD k0sctl apply --config "$CFG"
  fi
  ;;
uninstall)
  runCMD k0sctl reset --config "$CFG" --force
  ;;
backup)
  assertDir "$BAK"
  runCMD k0sctl backup --config "$CFG"
  mapfile -t archives < <(find "$(pwd)" -maxdepth 1 -name "${K0SCTL_PREFIX_BAK}*${K0SCTL_SUFFIX_BAK:-tar.gz}")
  for archiveHome in "${archives[@]}"; do
    assertFile "$archiveHome"
    archive="${archiveHome##*/}"
    printFunction "openssl $cipher -in $archive"
    openssl "$cipher" -in "$archive" -out "$archive".b64 -pass "$password" -a -pbkdf2
    runCMD ln -s "$archive".b64 -T "$latest"
    runCMD mv -n "$archive".b64 "$latest" -t "$BAK"
    echo "saved $archive.b64 as $latest" >"$BAK/.message"
  done
  ;;
*)
  exit 1 # EPERM Operation not permitted
  ;;
esac
