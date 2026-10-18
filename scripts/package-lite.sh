#!/usr/bin/env bash
set -euo pipefail
source_file="$1"
goos="$2"
output="$3"
version="$4"
dest="$5"
profile="${6:-}"
scripts="$(cd "$(dirname "$0")" && pwd)"
case "$profile" in
  gvisor) qualifier='' ;;
  no-gvisor) qualifier='-no-gvisor' ;;
  *) printf 'Unknown Lite capability profile: %s\n' "$profile" >&2; exit 2 ;;
esac
mkdir -p "$dest"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
name="mihomo-lite-$goos-$output$qualifier"
ext=''
[[ "$goos" != windows ]] || ext='.exe'
archive() {
  local name="$1"
  if [[ "$goos" == windows ]]; then
    if command -v zip >/dev/null 2>&1; then
      (cd "$work" && zip -q - "$name$ext") > "$dest/$name-$version.zip"
    else
      (cd "$work" && 7z a -tzip "$name.zip" "$name$ext" >/dev/null)
      cp "$work/$name.zip" "$dest/$name-$version.zip"
    fi
  else
    gzip -c "$work/$name" > "$dest/$name-$version.gz"
  fi
}
cp "$source_file" "$work/$name$ext"
archive "$name"
if grep -Fxq "$goos-$output" "$scripts/upx-targets.txt"; then
  cp "$source_file" "$work/$name-upx$ext"
  "${UPX_BIN:-upx}" --best "$work/$name-upx$ext"
  "${UPX_BIN:-upx}" -t "$work/$name-upx$ext"
  archive "$name-upx"
fi
