#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

usage() {
  cat <<EOF
usage: $(basename "$0") [swift test args...]

Run swift test for every package in this repository, one at a time.

examples:
  $(basename "$0")
  $(basename "$0") --filter AppTests
EOF
}

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.bareRepository
export GIT_CONFIG_VALUE_0=all

mapfile -t package_manifests < <(
  find "${project_root}" \
    -path '*/.build' -prune -o \
    -path '*/.git' -prune -o \
    -name Package.swift -print | sort
)

for package_manifest in "${package_manifests[@]}"; do
  package_path="$(dirname "${package_manifest}")"
  package_name="$(basename "${package_path}")"

  echo "==> swift test --package-path ${package_name}"
  swift test --package-path "${package_path}" "$@"
done