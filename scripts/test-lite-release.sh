#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# Stable tag pushes alone may publish stable releases and Docker latest.
test "$(bash scripts/release-channel.sh push v1.20.0)" = $'prerelease=false\nlatest=true'
test "$(bash scripts/release-channel.sh push v1.20.0-rc.1)" = $'prerelease=true\nlatest=false'
test "$(bash scripts/release-channel.sh workflow_dispatch v1.20.0)" = $'prerelease=true\nlatest=false'
test "$(bash scripts/release-channel.sh workflow_dispatch v1.20.0-rc.1)" = $'prerelease=true\nlatest=false'
printf 'original binary\n' > "$work/mihomo.exe"
bash scripts/package-lite.sh "$work/mihomo.exe" windows arm64 v1.2.3 "$work/assets"
test -s "$work/assets/mihomo-lite-windows-arm64-v1.2.3.zip"
bash scripts/check-assets.sh windows arm64 v1.2.3 "$work/assets"
rm "$work/assets/mihomo-lite-windows-arm64-v1.2.3.zip"
if bash scripts/check-assets.sh windows arm64 v1.2.3 "$work/assets"; then
  printf 'missing required asset was accepted\n' >&2; exit 1
fi
# An admitted target must fail when UPX fails, retaining the original binary.
printf '#!/usr/bin/env bash\nexit 1\n' > "$work/upx"
chmod +x "$work/upx"
if UPX_BIN="$work/upx" bash scripts/package-lite.sh "$work/mihomo.exe" windows amd64-v1 v1.2.3 "$work/failed"; then
  printf 'UPX failure was accepted\n' >&2; exit 1
fi
test "$(<"$work/mihomo.exe")" = 'original binary'
if bash scripts/check-assets.sh windows amd64-v1 v1.2.3 "$work/failed"; then
  printf 'missing admitted UPX asset was accepted\n' >&2; exit 1
fi
bash scripts/package-lite.sh "$work/mihomo.exe" linux arm64 v1.2.3 "$work/linux"
bash scripts/check-assets.sh linux arm64 v1.2.3 "$work/linux"
gzip -dc "$work/linux/mihomo-lite-linux-arm64-v1.2.3.gz" > "$work/unpacked"
cmp "$work/mihomo.exe" "$work/unpacked"
# A corrupted download must fail SHA-256 validation before extraction/execution.
mkdir "$work/fake-bin"
printf '#!/usr/bin/env bash\nwhile [[ $# -gt 0 ]]; do\n  if [[ "$1" == -o ]]; then printf corrupt > "$2"; exit 0; fi\n  shift\ndone\nexit 1\n' > "$work/fake-bin/curl"
chmod +x "$work/fake-bin/curl"
if PATH="$work/fake-bin:$PATH" bash scripts/install-upx.sh "$work/tool"; then
  printf 'corrupt UPX download was accepted\n' >&2; exit 1
fi
if compgen -G "$work/tool/download.*/extracted/*" >/dev/null; then
  printf 'corrupt UPX archive was extracted\n' >&2; exit 1
fi
printf 'Lite release boundary checks passed\n'
