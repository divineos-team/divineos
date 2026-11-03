#!/usr/bin/env bash
# File-operation tests in a temp dir; gio and bsdtar are stubs that log their calls.
#   bash pkgs/devine-files/test.sh
set -euo pipefail

op="$(cd "$(dirname "$0")" && pwd)/devine-files-op"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/a" "$tmp/b"
cat >"$tmp/bin/gio" <<STUB
#!/usr/bin/env bash
echo "gio \$*" >>"$tmp/log"
STUB
cat >"$tmp/bin/bsdtar" <<STUB
#!/usr/bin/env bash
# bsdtar -a -cf ZIP -C DIR NAME...: logs the call and makes ZIP
if [[ \$1 == -a ]]; then echo "bsdtar \$*" >>"$tmp/log"; touch "\$3"; exit; fi
# bsdtar -xf ARCHIVE -C DIR: "bad.zip" fails, anything else yields one file
[[ \$2 == */bad.zip ]] && exit 1
touch "\$4/extracted"
STUB
chmod +x "$tmp/bin/"*
run() { PATH="$tmp/bin:$PATH" bash "$op" "$@"; }
pass() { printf 'ok   %s\n' "$1"; }
fails() {
	if run "$@" 2>/dev/null; then
		printf 'FAIL: succeeded: %q\n' "$*"
		exit 1
	fi
}

cd "$tmp"
echo one >a/photo.jpg
echo two >b/photo.jpg
mkdir a/dir && echo x >a/dir/f
run copy b a/photo.jpg a/dir
[[ $(cat b/photo.jpg) == two && $(cat "b/photo 2.jpg") == one && -f b/dir/f && -f a/dir/f ]]
run copy b a/photo.jpg a/dir
[[ -f "b/photo 3.jpg" && -f "b/dir 2/f" ]]
pass "copy never overwrites: photo 2.jpg, photo 3.jpg, dir 2"

touch a/backup.tar.gz b/backup.tar.gz a/.bashrc b/.bashrc
run copy b a/backup.tar.gz a/.bashrc
[[ -f "b/backup 2.tar.gz" && -f "b/.bashrc 2" ]]
pass "numbering keeps .tar.gz together and dotfiles whole"

run move b a/photo.jpg
[[ ! -e a/photo.jpg && -f "b/photo 4.jpg" ]]
run move b b/photo.jpg
[[ -f b/photo.jpg && ! -e "b/photo 5.jpg" ]]
pass "move renames on clash; moving into its own folder does nothing"

fails copy b a/missing
fails copy a/nonexistent-dir b/photo.jpg
pass "missing sources and destinations are errors"

touch a/pics.tar.gz a/Stuff.ZIP a/bad.zip
run extract b a/pics.tar.gz a/Stuff.ZIP
[[ -f b/pics/extracted && -f b/Stuff/extracted ]]
run extract b a/pics.tar.gz
[[ -f "b/pics 2/extracted" ]]
fails extract b a/bad.zip
[[ ! -e b/bad ]]
pass "extract: one folder per archive, numbered on clash, removed on failure"

[[ $(run compress b a/dir) == "b/dir.zip" ]]
grep -qx "bsdtar -a -cf b/dir.zip -C a dir" log
touch a/-x
[[ $(run compress b a/dir a/-x) == "b/Archive.zip" ]]
grep -qx "bsdtar -a -cf b/Archive.zip -C a dir ./-x" log
[[ $(run compress b a/dir) == "b/dir 2.zip" ]]
fails compress b a/dir b/photo.jpg
pass "compress: one zip named after the item or Archive, numbered, one folder at a time"

first=$(run mkdir b)
second=$(run mkdir b)
[[ $first == "b/New Folder" && $second == "b/New Folder 2" ]]
pass "mkdir: New Folder, New Folder 2"

run rename b/photo.jpg holiday.jpg
[[ -f b/holiday.jpg && ! -e b/photo.jpg ]]
fails rename b/holiday.jpg "photo 2.jpg"
fails rename b/holiday.jpg ../escape.jpg
fails rename b/holiday.jpg ..
fails rename b/holiday.jpg ""
[[ -f b/holiday.jpg && $(cat "b/photo 2.jpg") == one ]]
run rename b/holiday.jpg holiday.jpg
pass "rename refuses taken names, slashes, '..' and empty"

run trash "b/photo 2.jpg" "b/dir 2"
grep -qx "gio trash -- b/photo 2.jpg b/dir 2" log
pass "trash goes through gio"
