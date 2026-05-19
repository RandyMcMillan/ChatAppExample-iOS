#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

package_name="${1:?usage: $(basename "$0") <package-dir> [swift build args...]}"
shift

if [[ "${1:-}" == "build" ]]; then
  shift
fi

export GIT_CONFIG_COUNT="${GIT_CONFIG_COUNT:-1}"
export GIT_CONFIG_KEY_0="${GIT_CONFIG_KEY_0:-safe.bareRepository}"
export GIT_CONFIG_VALUE_0="${GIT_CONFIG_VALUE_0:-all}"

exec swift build --package-path "${project_root}/${package_name}" "$@"
