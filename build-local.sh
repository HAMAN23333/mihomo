#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Windows Git Bash may predate Scoop's PATH update.
if ! command -v go >/dev/null 2>&1; then
  scoop_go="/c/Users/HAMAN/scoop/apps/go/current/bin"
  if [[ -x "$scoop_go/go.exe" ]]; then
    export PATH="$scoop_go:$PATH"
  fi
fi
export CGO_ENABLED=0 GOTOOLCHAIN=local
profile=both
with_upx=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || { printf 'Missing value for --profile\n' >&2; exit 2; }
      profile="$2"
      shift 2
      ;;
    --upx)
      with_upx=true
      shift
      ;;
    *)
      printf 'Usage: %s [--profile gvisor|no-gvisor|both] [--upx]\n' "$0" >&2
      exit 2
      ;;
  esac
done
case "$profile" in
  gvisor) profiles=(gvisor) ;;
  no-gvisor) profiles=(no-gvisor) ;;
  both) profiles=(gvisor no-gvisor) ;;
  *) printf 'Unknown Lite capability profile: %s\n' "$profile" >&2; exit 2 ;;
esac
version="custom-$(git rev-parse --short HEAD)"
build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ldflags="-X github.com/metacubex/mihomo/constant.Version=$version -X github.com/metacubex/mihomo/constant.BuildTime=$build_time -w -s -buildid="
mkdir -p bin/local
produced=()

go version
go mod download
go mod verify
for capability in "${profiles[@]}"; do
  case "$capability" in
    gvisor)
      tags="$(<scripts/lite-tags.txt)"
      qualifier=''
      ;;
    no-gvisor)
      tags="$(<scripts/lite-no-gvisor-tags.txt)"
      qualifier='-no-gvisor'
      ;;
  esac
  for target in windows-amd64 linux-amd64 linux-arm64; do
    os="${target%-*}"
    arch="${target#*-}"
    output="$arch"
    [[ "$arch" != amd64 ]] || output=amd64-v3
    name="mihomo-lite-$os-$output$qualifier"
    [[ "$os" != windows ]] || name="$name.exe"
    path="bin/local/$name"
    GOOS="$os" GOARCH="$arch" GOAMD64=v3 GOARM64=v8.0 \
      go build -tags "$tags" -trimpath -ldflags "$ldflags" -o "$path" .
    bash scripts/check-lite.sh "$path" "$capability" --metadata-only
    produced+=("$name")
    if "$with_upx"; then
      if grep -Fxq "$os-$output" scripts/upx-targets.txt; then
        upx_name="${name%.exe}-upx"
        [[ "$os" != windows ]] || upx_name="$upx_name.exe"
        cp "$path" "bin/local/$upx_name"
        upx --best "bin/local/$upx_name"
        upx -t "bin/local/$upx_name"
        produced+=("$upx_name")
      else
        printf 'Skipping UPX for unadmitted target: %s (%s)\n' "$os-$output" "$capability"
      fi
    fi
  done
done

: > bin/local/build-info.txt
for name in "${produced[@]}"; do
  file "bin/local/$name"
  go version -m "bin/local/$name" >> bin/local/build-info.txt
 done
(
  cd bin/local
  sha256sum "${produced[@]}" > SHA256SUMS
)
