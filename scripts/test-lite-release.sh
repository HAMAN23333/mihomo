#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# Stable tag pushes alone may publish stable releases and Docker latest.
test "$(bash scripts/release-channel.sh push v1.20.0)" = $'prerelease=false\nlatest=true'
test "$(bash scripts/release-channel.sh push v1.20.0-rc.1)" = $'prerelease=true\nlatest=false'
test "$(bash scripts/release-channel.sh workflow_dispatch v1.20.0)" = $'prerelease=true\nlatest=false'
test "$(bash scripts/release-channel.sh workflow_dispatch v1.20.0-rc.1)" = $'prerelease=true\nlatest=false'

printf 'original binary\n' > "$work/mihomo.exe"
bash scripts/package-lite.sh "$work/mihomo.exe" windows arm64 v1.2.3 "$work/assets" gvisor
bash scripts/package-lite.sh "$work/mihomo.exe" windows arm64 v1.2.3 "$work/assets" no-gvisor
test -s "$work/assets/mihomo-lite-windows-arm64-v1.2.3.zip"
test -s "$work/assets/mihomo-lite-windows-arm64-no-gvisor-v1.2.3.zip"
test "$(unzip -Z1 "$work/assets/mihomo-lite-windows-arm64-v1.2.3.zip")" = mihomo-lite-windows-arm64.exe
test "$(unzip -Z1 "$work/assets/mihomo-lite-windows-arm64-no-gvisor-v1.2.3.zip")" = mihomo-lite-windows-arm64-no-gvisor.exe
if bash scripts/package-lite.sh "$work/mihomo.exe" windows arm64 v1.2.3 "$work/invalid" unknown; then
  printf 'unknown capability profile was accepted by packager\n' >&2; exit 1
fi
if bash scripts/check-lite.sh "$work/mihomo.exe" unknown --metadata-only; then
  printf 'unknown capability profile was accepted by binary checker\n' >&2; exit 1
fi
bash scripts/check-assets.sh windows arm64 v1.2.3 "$work/assets"
cp -R "$work/assets" "$work/missing-gvisor"
cp -R "$work/assets" "$work/missing-no-gvisor"
rm "$work/missing-gvisor/mihomo-lite-windows-arm64-v1.2.3.zip"
rm "$work/missing-no-gvisor/mihomo-lite-windows-arm64-no-gvisor-v1.2.3.zip"
for directory in missing-gvisor missing-no-gvisor; do
  if bash scripts/check-assets.sh windows arm64 v1.2.3 "$work/$directory"; then
    printf 'missing required asset was accepted: %s\n' "$directory" >&2; exit 1
  fi
done

# An admitted target must fail when UPX fails for either profile, retaining the original binary.
printf '#!/usr/bin/env bash\nexit 1\n' > "$work/upx-fail"
chmod +x "$work/upx-fail"
for profile in gvisor no-gvisor; do
  if UPX_BIN="$work/upx-fail" bash scripts/package-lite.sh "$work/mihomo.exe" windows amd64-v1 v1.2.3 "$work/failed-$profile" "$profile"; then
    printf 'UPX failure was accepted for %s\n' "$profile" >&2; exit 1
  fi
done
test "$(<"$work/mihomo.exe")" = 'original binary'

# Both standard and UPX packaging forms are required for an admitted target.
printf '#!/usr/bin/env bash\nexit 0\n' > "$work/upx-pass"
chmod +x "$work/upx-pass"
for profile in gvisor no-gvisor; do
  UPX_BIN="$work/upx-pass" bash scripts/package-lite.sh "$work/mihomo.exe" windows amd64-v1 v1.2.3 "$work/admitted" "$profile"
done
bash scripts/check-assets.sh windows amd64-v1 v1.2.3 "$work/admitted"
test "$(unzip -Z1 "$work/admitted/mihomo-lite-windows-amd64-v1-no-gvisor-upx-v1.2.3.zip")" = mihomo-lite-windows-amd64-v1-no-gvisor-upx.exe
rm "$work/admitted/mihomo-lite-windows-amd64-v1-no-gvisor-upx-v1.2.3.zip"
if bash scripts/check-assets.sh windows amd64-v1 v1.2.3 "$work/admitted"; then
  printf 'missing admitted UPX asset was accepted\n' >&2; exit 1
fi

bash scripts/package-lite.sh "$work/mihomo.exe" linux arm64 v1.2.3 "$work/linux" gvisor
bash scripts/package-lite.sh "$work/mihomo.exe" linux arm64 v1.2.3 "$work/linux" no-gvisor
bash scripts/check-assets.sh linux arm64 v1.2.3 "$work/linux"
gzip -dc "$work/linux/mihomo-lite-linux-arm64-v1.2.3.gz" > "$work/unpacked"
cmp "$work/mihomo.exe" "$work/unpacked"

# Docker must continue selecting the unqualified gVisor standard archive exactly.
mkdir -p "$work/docker-both/bin" "$work/docker-no-gvisor/bin"
printf 'v1.2.3\n' > "$work/docker-both/bin/version.txt"
printf 'v1.2.3\n' > "$work/docker-no-gvisor/bin/version.txt"
cp "$work/linux/mihomo-lite-linux-arm64-v1.2.3.gz" "$work/docker-both/bin/"
cp "$work/linux/mihomo-lite-linux-arm64-no-gvisor-v1.2.3.gz" "$work/docker-both/bin/"
cp "$work/linux/mihomo-lite-linux-arm64-no-gvisor-v1.2.3.gz" "$work/docker-no-gvisor/bin/"
test "$(cd "$work/docker-both" && TARGETPLATFORM=linux/arm64 sh "$root/docker/file-name.sh")" = mihomo-lite-linux-arm64-v1.2.3.gz
if (cd "$work/docker-no-gvisor" && TARGETPLATFORM=linux/arm64 sh "$root/docker/file-name.sh"); then
  printf 'Docker accepted a no-GVisor-only asset set\n' >&2; exit 1
fi

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
