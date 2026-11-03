#!/usr/bin/env bash
# Routing test: runs divine-pkg against stub pacman/paru/curl/podman/distrobox/sudo that
# only log their calls, then checks what would have run. No network, no root.
#   bash pkgs/divine-pkg/test.sh
# shellcheck disable=SC2016 # stub bodies are code for the stub, expanded when it runs
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"
log=$tmp/log

stub() { # stub <name> <body>: logs "<name> <args>" then runs body
	printf '#!/usr/bin/env bash\necho "%s $*" >> %q\n%s\n' "$1" "$log" "${2:-}" >"$tmp/bin/$1"
	chmod +x "$tmp/bin/$1"
}
stub sudo
stub paru
stub pacman 'case $1 in -Si) [[ $3 == htop ]] ;; -Qq) [[ $3 == htop ]] ;; esac'
stub curl '[[ $* == *arg%5B%5D=yay* ]] && echo "{\"resultcount\":1}" || echo "{\"resultcount\":0}"'
stub podman "[[ -f $tmp/box ]]"
stub distrobox "
[[ \$1 == create ]] && touch $tmp/box && exit
shift 3 # enter debian --
case \$1 in
apt-cache) [[ \$* == *cowsay* ]] ;;
dpkg) printf '%s\n' /usr/games/cowsay /usr/bin/ls /usr/share/applications/cowsay.desktop /usr/share/doc/cowsay ;;
dpkg-deb) echo localdeb ;;
esac"

echo "$(id -un):100000:65536" >"$tmp/subuid"
run() {
	: >"$log"
	HOME=$tmp/home XDG_DATA_HOME=$tmp/home/share DIVINE_PKG_SUBUID=$tmp/subuid PATH="$tmp/bin:$PATH" \
		bash "$here/divine-pkg" "$@" </dev/null
}
expect() { grep -qF -- "$1" "$log" || { printf 'FAIL: expected "%s" in:\n' "$1"; cat "$log"; exit 1; }; }
reject() { ! grep -qF -- "$1" "$log" || { printf 'FAIL: did not expect "%s"\n' "$1"; exit 1; }; }
pass() { printf 'ok   %s\n' "$1"; }

run install htop >/dev/null
expect "sudo pacman -S --needed htop"
reject "paru"
pass "repo package goes to pacman"

run install yay >/dev/null
expect "paru -S --aur --needed yay"
pass "AUR package goes to paru"

if run install cowsay >/dev/null 2>&1; then echo "FAIL: created a container without asking"; exit 1; fi
reject "distrobox create"
pass "no terminal, no --yes: never creates the container unasked"

run --yes install cowsay >/dev/null
expect "distrobox create --yes --no-entry --name debian"
expect "distrobox enter debian -- sudo apt-get install -y cowsay"
expect "distrobox-export --bin /usr/games/cowsay"
reject "distrobox-export --bin /usr/bin/ls"
expect "distrobox-export --app cowsay"
grep -qx "bin /usr/games/cowsay" "$tmp/home/share/divine-pkg/debian/cowsay"
pass "Debian package: container created, commands exported, host's ls not shadowed"

run install deb:cowsay >/dev/null
reject "distrobox create"
expect "sudo apt-get install -y cowsay"
pass "deb: prefix skips resolution and reuses the container"

touch "$tmp/home/local.deb"
run install "$tmp/home/local.deb" >/dev/null
expect "dpkg-deb -f /run/host$(realpath "$tmp/home/local.deb") Package"
expect "apt-get install -y /run/host$(realpath "$tmp/home/local.deb")"
pass ".deb file installs through /run/host"

run remove cowsay >/dev/null
expect "distrobox-export --bin /usr/games/cowsay --export-path $tmp/home/.local/bin --delete"
expect "sudo apt-get remove -y --autoremove cowsay"
[[ ! -e $tmp/home/share/divine-pkg/debian/cowsay ]]
pass "Debian removal unexports and forgets"

run remove htop >/dev/null
expect "sudo pacman -Rns htop"
pass "host removal goes to pacman"

rm "$tmp/box"
: >"$tmp/subuid"
if run --yes install deb:cowsay >/dev/null 2>&1; then echo "FAIL: created a container without subuids"; exit 1; fi
reject "distrobox create"
pass "missing subordinate IDs stop before podman fails cryptically"

if run install 'evil;rm' >/dev/null 2>&1; then echo "FAIL: accepted a bad name"; exit 1; fi
pass "rejects invalid package names"

if run install nothing-here >/dev/null 2>&1; then echo "FAIL: installed a missing package"; exit 1; fi
pass "unknown package fails cleanly"

echo "all divine-pkg routing tests passed"
