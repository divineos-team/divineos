#!/usr/bin/env bash
# Builds the divineOS XCursor theme: make-cursors.sh <svg dir> <cursors.list> <out dir>
# Each cursor is rendered at every size in $sizes, frame by frame for animated ones, then packed
# by xcursorgen into <out>/cursors/<name>, with its aliases as symlinks.
set -euo pipefail

svg=$1 list=$2 out=$3
sizes=(24 32 48 64 96)
delay=50 # ms per frame

work=$out/.work
mkdir -p "$work" "$out/cursors"
while read -r name file hx hy rot frames aliases; do
  [[ -z $name || $name == \#* ]] && continue
  : > "$work/$name.cfg"
  d=""
  ((frames > 1)) && d=" $delay"
  for ((f = 0; f < frames; f++)); do
    sed "s/{ROT}/$((rot + f * 360 / frames))/g" "$svg/$file.svg" > "$work/frame.svg"
    for s in "${sizes[@]}"; do
      png=$work/$name-$f-$s.png
      rsvg-convert -w "$s" -h "$s" "$work/frame.svg" -o "$png"
      # hotspot scaled from the 32-unit viewBox, rounded
      printf '%s %s %s %s%s\n' "$s" $(((hx * s + 16) / 32)) $(((hy * s + 16) / 32)) "$png" "$d" >> "$work/$name.cfg"
    done
  done
  xcursorgen "$work/$name.cfg" "$out/cursors/$name"
  for a in $aliases; do
    ln -sf "$name" "$out/cursors/$a"
  done
done < "$list"
rm -r "$work"
