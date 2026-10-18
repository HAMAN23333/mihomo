#!/usr/bin/env bash
lite_profile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lite_profile() {
  case "$1" in
    gvisor)
      LITE_PROFILE_TAGS_FILE="$lite_profile_dir/lite-tags.txt"
      LITE_PROFILE_QUALIFIER=''
      LITE_PROFILE_EXPECT_GVISOR=true
      ;;
    no-gvisor)
      LITE_PROFILE_TAGS_FILE="$lite_profile_dir/lite-no-gvisor-tags.txt"
      LITE_PROFILE_QUALIFIER='-no-gvisor'
      LITE_PROFILE_EXPECT_GVISOR=false
      ;;
    *)
      printf 'Unknown Lite capability profile: %s\n' "$1" >&2
      return 2
      ;;
  esac
}
