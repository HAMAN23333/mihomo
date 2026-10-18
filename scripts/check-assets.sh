#!/usr/bin/env bash
set -euo pipefail
goos="$1"; output="$2"; version="$3"; dir="$4"
scripts="$(cd "$(dirname "$0")" && pwd)"
name="mihomo-lite-$goos-$output"
ext=gz
[[ "$goos" != windows ]] || ext=zip
required=("$name-$version.$ext" "$name-no-gvisor-$version.$ext")
if grep -Fxq "$goos-$output" "$scripts/upx-targets.txt"; then
  required+=("$name-upx-$version.$ext" "$name-no-gvisor-upx-$version.$ext")
fi
[[ -z "${5:-}" ]] || required+=("$name-$version.deb")
[[ -z "${6:-}" ]] || required+=("$name-$version.rpm")
[[ -z "${7:-}" ]] || required+=("$name-$version.pkg.tar.zst")
for asset in "${required[@]}"; do
  if [[ ! -s "$dir/$asset" ]]; then
    printf 'Missing required asset: %s\n' "$asset" >&2
    exit 1
  fi
  case "$asset" in
    *.zip) unzip -tq "$dir/$asset" ;;
    *.gz) gzip -t "$dir/$asset" ;;
  esac
done
