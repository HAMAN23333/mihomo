#!/usr/bin/env bash
set -euo pipefail
binary="$1"
if [[ "${2:-}" != --packed ]]; then
  info="$(go version -m "$binary")"
  for tag in with_gvisor no_tailscale no_zerotier no_easytier; do
    if ! grep -E -- '-tags=.*' <<< "$info" | grep -qw "$tag"; then
      printf 'Missing Lite build tag: %s\n' "$tag" >&2; exit 1
    fi
  done
  if grep -Eq 'dep[[:space:]]+github.com/(metacubex/(tailscale|zerotier-go)|easytier/easytier/easytier-go)[[:space:]]' <<< "$info"; then
    printf 'Excluded SDK linked into %s\n' "$binary" >&2; exit 1
  fi
fi
[[ "${2:-}" != --metadata-only ]] || exit 0
# Resolve the executable before changing to isolated configuration directories.
binary="$(cd "$(dirname "$binary")" && pwd)/$(basename "$binary")"
version="$("$binary" -v)"
for tag in with_gvisor no_tailscale no_zerotier no_easytier; do
  grep -qw "$tag" <<< "$version"
done
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
