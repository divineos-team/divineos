#!/usr/bin/env bash
# Validation test for the root helper: everything here uses --dry-run, so nothing is written.
#   bash pkgs/devine-tweaks/test.sh
set -euo pipefail
helper="$(cd "$(dirname "$0")" && pwd)/apply-sysctl"

pass() { printf 'ok   %s\n' "$1"; }
refuses() {
	if bash "$helper" --dry-run "$@" >/dev/null 2>&1; then
		printf 'FAIL: accepted %q\n' "$*"
		exit 1
	fi
}

out=$(bash "$helper" --dry-run vm.swappiness=180 vm.vfs_cache_pressure=50 net.ipv4.tcp_congestion_control=bbr fs.inotify.max_user_watches=524288)
grep -qx "vm.swappiness = 180" <<<"$out"
grep -qx "net.ipv4.tcp_congestion_control = bbr" <<<"$out"
[[ $(grep -c ' = ' <<<"$out") == 4 ]]
pass "valid settings render to sysctl.d lines"

for v in 0 99 100 199 200; do bash "$helper" --dry-run "vm.swappiness=$v" >/dev/null; done
pass "swappiness accepts 0–200"

refuses vm.swappiness=201
refuses vm.swappiness=-1
refuses vm.swappiness=1e3
pass "swappiness rejects out-of-range values"

refuses kernel.core_pattern=/tmp/x
refuses kernel.modprobe=/tmp/evil
pass "keys outside the allowlist are refused"

refuses "vm.swappiness=10"$'\n'"kernel.modprobe=/tmp/evil"
refuses "vm.swappiness=10; reboot"
refuses vm.swappiness
refuses net.ipv4.tcp_congestion_control=bbr2
pass "injection, missing values and unknown choices are refused"

if bash "$helper" >/dev/null 2>&1; then echo "FAIL: ran without arguments"; exit 1; fi
pass "no arguments prints usage"

echo "all apply-sysctl tests passed"
