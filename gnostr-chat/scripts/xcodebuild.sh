#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

project="${XCODE_PROJECT:-gnostr-chat.xcodeproj}"
scheme="${XCODE_SCHEME:-gnostr-iphone}"
configuration="${XCODE_CONFIGURATION:-Debug}"
destination="${XCODE_DESTINATION:-platform=iOS Simulator,name=iPhone 16}"
action="${1:-build}"

if (($#)); then
  shift
fi

exec xcodebuild \
  -project "${project_root}/${project}" \
  -scheme "${scheme}" \
  -configuration "${configuration}" \
  -destination "${destination}" \
  "${action}" \
  "$@"
