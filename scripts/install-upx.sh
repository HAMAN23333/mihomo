#!/usr/bin/env bash
set -euo pipefail
# Reviewed 2026-10-17 against https://github.com/upx/upx/releases/tag/v5.0.2.
# Verify before extracting or executing anything from the archive.
dest="$1"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    archive=upx-5.0.2-amd64_linux.tar.xz
    digest=ddc2654063fe4dc80d95b420788494e4db078ebb01a650692d623b5a9906e61e ;;
  MINGW*-x86_64|MSYS*-x86_64)
    archive=upx-5.0.2-win64.zip
    digest=1cff6d6ee01c404d4a1ae56003056bd4cfa28d0a5cea1d0950daaf872a4facc9 ;;
  *) printf 'Unsupported UPX tool host\n' >&2; exit 1 ;;
esac
# Every downloaded archive lives in its own newly created directory.
mkdir -p "$dest"
work="$(mktemp -d "$dest/download.XXXXXXXX")"
curl --fail --location --silent --show-error "https://github.com/upx/upx/releases/download/v5.0.2/$archive" -o "$work/$archive"
printf '%s  %s\n' "$digest" "$work/$archive" | sha256sum -c - >&2
case "$archive" in
  *.zip) unzip -q "$work/$archive" -d "$work/extracted"; tool="$work/extracted/upx-5.0.2-win64/upx.exe" ;;
  *.tar.xz) mkdir "$work/extracted"; tar -xJf "$work/$archive" -C "$work/extracted"; tool="$work/extracted/upx-5.0.2-amd64_linux/upx" ;;
esac
printf '%s/%s\n' "$(cd "$(dirname "$tool")" && pwd)" "$(basename "$tool")"
