#!/usr/bin/env bash
set -euo pipefail
# The caller validates the version before classifying the release.
if [[ "$1" == workflow_dispatch || "$2" == *-* ]]; then
  printf 'prerelease=true\nlatest=false\n'
else
  printf 'prerelease=false\nlatest=true\n'
fi
