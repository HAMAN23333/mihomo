#!/usr/bin/env bash
set -euo pipefail
binary="$1"
profile="$2"
mode="${3:-}"
scripts="$(cd "$(dirname "$0")" && pwd)"
source "$scripts/lite-profile.sh"
lite_profile "$profile"
expect_gvisor="$LITE_PROFILE_EXPECT_GVISOR"
expected_tags="$(<"$LITE_PROFILE_TAGS_FILE")"
case "$mode" in
  ''|--packed|--metadata-only) ;;
  *) printf 'Unknown Lite check mode: %s\n' "$mode" >&2; exit 2 ;;
esac
if [[ "$mode" != --packed ]]; then
  info="$(go version -m "$binary")"
  tags="$(grep -E -- '-tags=.*' <<< "$info" || true)"
  for tag in $expected_tags; do
    if ! grep -qw "$tag" <<< "$tags"; then
      printf 'Missing Lite build tag: %s\n' "$tag" >&2; exit 1
    fi
  done
  if ! "$expect_gvisor" && grep -qw with_gvisor <<< "$tags"; then
    printf 'Unexpected no-GVisor build tag: with_gvisor\n' >&2; exit 1
  fi
  if grep -Eq 'dep[[:space:]]+github.com/(metacubex/(tailscale|zerotier-go)|easytier/easytier/easytier-go)[[:space:]]' <<< "$info"; then
    printf 'Excluded SDK linked into %s\n' "$binary" >&2; exit 1
  fi
  if ! "$expect_gvisor" && grep -Eq 'dep[[:space:]]+github.com/metacubex/gvisor[[:space:]]' <<< "$info"; then
    printf 'gVisor linked into no-GVisor binary: %s\n' "$binary" >&2; exit 1
  fi
fi
[[ "$mode" != --metadata-only ]] || exit 0
# Resolve the executable before changing to isolated configuration directories.
binary="$(cd "$(dirname "$binary")" && pwd)/$(basename "$binary")"
version="$("$binary" -v)"
for tag in $expected_tags; do
  grep -qw "$tag" <<< "$version"
done
if ! "$expect_gvisor"; then
  ! grep -qw with_gvisor <<< "$version"
  exit 0
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
printf 'mode: direct\nrules: []\n' > "$work/config.yaml"
"$binary" -t -d "$work" -f "$work/config.yaml"
for protocol in tailscale zerotier easytier; do
  printf 'mode: direct\nproxies:\n  - name: disabled\n    type: %s\n' "$protocol" > "$work/config.yaml"
  [[ "$protocol" != zerotier ]] || printf '    network: "0123456789abcdef"\n' >> "$work/config.yaml"
  printf 'rules: []\n' >> "$work/config.yaml"
  if result="$("$binary" -t -d "$work" -f "$work/config.yaml" 2>&1)"; then
    printf 'Disabled outbound accepted: %s\n' "$protocol" >&2; exit 1
  fi
  if ! grep -qi "$protocol.*disabled" <<< "$result"; then
    printf 'Expected disabled %s error, got: %s\n' "$protocol" "$result" >&2; exit 1
  fi
done
printf 'Lite acceptance checks passed: %s\n' "$binary"
