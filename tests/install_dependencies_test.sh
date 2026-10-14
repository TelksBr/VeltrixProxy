#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Load the installer functions without running installation or its cleanup trap.
source <(sed '$d' "$repo_dir/install.sh")
trap - EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

SKIP_HEADER=true
# Exercise the real APT package command without changing the host packages.
(
  package_commands=()
  run_privileged() { package_commands+=("$*"); }
  install_packages apt coreutils
  [[ "${package_commands[0]}" == "apt-get update -qq" ]] || fail "APT index refresh"
  [[ "${package_commands[1]}" == "env DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y coreutils" ]] || fail "APT must restore files from installed packages"
)

install_available=false
checksum_available=true
package_result=success
package_calls=0

has_command() {
  case "$1" in
    install) [[ "$install_available" == true ]] ;;
    sha256sum | gsha256sum | shasum) [[ "$checksum_available" == true ]] ;;
    *) return 0 ;;
  esac
}

detect_package_manager() { echo apt; }

install_packages() {
  [[ "$*" == "apt coreutils" ]] || fail "unexpected package request: $*"
  package_calls=$((package_calls + 1))
  case "$package_result" in
    success) install_available=true; checksum_available=true ;;
    unchanged) return 0 ;;
    failure) return 1 ;;
  esac
}

[[ "$(get_missing_commands)" == install ]] || fail "missing install was not detected"
for pm in apt apk dnf yum pacman zypper; do
  [[ "$(commands_to_packages "$pm" install)" == coreutils ]] || fail "$pm install mapping"
  [[ "$(commands_to_packages "$pm" sha256sum install)" == coreutils ]] || fail "$pm coreutils deduplication"
done

ensure_dependencies
[[ "$install_available" == true && "$package_calls" == 1 ]] || fail "install was not repaired"
ensure_dependencies
[[ "$package_calls" == 1 ]] || fail "complete dependencies triggered a package install"

install_available=false
checksum_available=false
[[ "$(get_missing_commands)" == $'sha256sum\ninstall' ]] || fail "missing checksum and install detection"
ensure_dependencies
[[ "$install_available" == true && "$checksum_available" == true ]] || fail "coreutils repair failed"

install_available=false
package_result=unchanged
if output=$(ensure_dependencies 2>&1); then
  fail "dependencies succeeded with install still missing"
fi
[[ "$output" == *"Ainda faltam dependências após instalação: install"* ]] || fail "missing install diagnostic"

package_result=failure
if output=$(ensure_dependencies 2>&1); then
  fail "dependencies succeeded after package manager failure"
fi
[[ "$output" == *"Falha ao instalar dependências automaticamente."* ]] || fail "package failure diagnostic"

echo "PASS: installer dependency regression tests"
