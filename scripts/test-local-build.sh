#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/fake-bin"
printf '%s\n' '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [[ "$1" == version && $# == 1 ]]; then printf "go version go-test windows/amd64\n"; exit 0; fi' \
  'if [[ "$1" == mod ]]; then exit 0; fi' \
  'if [[ "$1" == version && "$2" == -m ]]; then cat "$3"; exit 0; fi' \
  'if [[ "$1" == build ]]; then' \
  '  tags=""; output=""' \
  '  while [[ $# -gt 0 ]]; do' \
  '    case "$1" in' \
  '      -tags) tags="$2"; shift 2 ;;' \
  '      -o) output="$2"; shift 2 ;;' \
  '      *) shift ;;' \
  '    esac' \
  '  done' \
  '  printf "fake binary\n build\t-tags=%s\n" "$tags" > "$output"' \
  '  exit 0' \
  'fi' \
  'printf "unexpected fake go command: %s\n" "$*" >&2; exit 1' > "$work/fake-bin/go"
chmod +x "$work/fake-bin/go"

run_build() {
  local profile="$1" expected_count="$2" output
  output="$work/$profile"
  PATH="$work/fake-bin:$PATH" LITE_OUTPUT_DIR="$output" bash build-local.sh --profile "$profile"
  test "$(wc -l < "$output/SHA256SUMS")" -eq "$expected_count"
  test "$(grep -c '^ build[[:space:]]' "$output/build-info.txt")" -eq "$expected_count"
}
run_build gvisor 3
test -s "$work/gvisor/mihomo-lite-windows-amd64-v3.exe"
! compgen -G "$work/gvisor/*no-gvisor*" >/dev/null
run_build no-gvisor 3
test -s "$work/no-gvisor/mihomo-lite-windows-amd64-v3-no-gvisor.exe"
! test -e "$work/no-gvisor/mihomo-lite-windows-amd64-v3.exe"
run_build both 6
test -s "$work/both/mihomo-lite-windows-amd64-v3.exe"
test -s "$work/both/mihomo-lite-windows-amd64-v3-no-gvisor.exe"
PATH="$work/fake-bin:$PATH" LITE_OUTPUT_DIR="$work/upx" bash build-local.sh --upx --profile both
test "$(wc -l < "$work/upx/SHA256SUMS")" -eq 6
! compgen -G "$work/upx/*-upx*" >/dev/null
printf 'Local Lite profile selection checks passed\n'
