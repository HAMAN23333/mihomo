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
with_upx=false
case "${1:-}" in
  '') ;;
  --upx) with_upx=true; command -v upx >/dev/null ;;
  *) printf 'Usage: %s [--upx]\n' "$0" >&2; exit 2 ;;
esac
tags="$(<scripts/lite-tags.txt)"
version="custom-$(git rev-parse --short HEAD)"
build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ldflags="-X github.com/metacubex/mihomo/constant.Version=$version -X github.com/metacubex/mihomo/constant.BuildTime=$build_time -w -s -buildid="
mkdir -p bin/local

go version
go mod download
go mod verify
for target in windows-amd64 linux-amd64 linux-arm64; do
  os="${target%-*}"
  arch="${target#*-}"
  name="mihomo-lite-$target"
  if [[ "$arch" == amd64 ]]; then name="$name-v3"; fi
  if [[ "$os" == windows ]]; then name="$name.exe"; fi
  GOOS="$os" GOARCH="$arch" GOAMD64=v3 GOARM64=v8.0 \
    go build -tags "$tags" -trimpath -ldflags "$ldflags" -o "bin/local/$name" .
  bash scripts/check-lite.sh "bin/local/$name" --metadata-only
  if "$with_upx"; then
    upx_name="${name%.exe}-upx"
    [[ "$os" != windows ]] || upx_name="$upx_name.exe"
    cp "bin/local/$name" "bin/local/$upx_name"
    upx --best "bin/local/$upx_name"
    upx -t "bin/local/$upx_name"
  fi
done
file bin/local/mihomo-lite-*
go version -m bin/local/mihomo-lite-windows-amd64-v3.exe > bin/local/build-info.txt
go version -m bin/local/mihomo-lite-linux-amd64-v3 >> bin/local/build-info.txt
go version -m bin/local/mihomo-lite-linux-arm64 >> bin/local/build-info.txt
(cd bin/local && sha256sum mihomo-lite-* > SHA256SUMS)
