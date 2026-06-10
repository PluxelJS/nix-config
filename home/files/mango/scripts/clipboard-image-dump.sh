#!/bin/sh
set -eu

out_dir="${XDG_CACHE_HOME:-$HOME/.cache}/mango/clipboard"
mkdir -p "$out_dir"

ts="$(date -Iseconds | tr ':' '-')"
types="$(wl-paste --list-types || true)"

echo "ts=$ts"
echo "types:"
printf "%s\n" "$types"

pick_type=""
for t in image/png image/jpeg image/webp image/bmp image/tiff; do
  if printf "%s\n" "$types" | grep -qx "$t"; then
    pick_type="$t"
    break
  fi
done

if [ -z "$pick_type" ]; then
  echo "no image/* in clipboard"
  exit 0
fi

case "$pick_type" in
  image/png)  ext=png ;;
  image/jpeg) ext=jpg ;;
  image/webp) ext=webp ;;
  image/bmp)  ext=bmp ;;
  image/tiff) ext=tiff ;;
  *)          ext=bin ;;
esac

out="$out_dir/$ts.$ext"
wl-paste --type "$pick_type" >"$out"

echo "saved=$out"
wc -c "$out" | sed 's/^/bytes: /'
file "$out" | sed 's/^/info: /'
command -v sha256sum >/dev/null 2>&1 && sha256sum "$out" | sed 's/^/sha256: /'

