#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"
source_root="${project_root}/cpp-libp2p-0.1.37"
build_root="${project_root}/build"

usage() {
  cat <<EOF
usage: $(basename "$0") [--verbose] [--configure-only]

Configure and build the vendored cpp-libp2p source tree for Apple targets.

The default build turns QUIC off because the upstream lsquic dependency is not
yet integrated into this repo's Apple toolchain path.
EOF
}

verbose=0
configure_only=0

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --verbose|-v)
      verbose=1
      ;;
    --configure-only)
      configure_only=1
      ;;
    *)
      echo "usage: $(basename "$0") [--verbose] [--configure-only]" >&2
      exit 1
      ;;
  esac
  shift
done

cmake_args=(
  -S "${source_root}"
  -B "${build_root}"
  -DTESTING=OFF
  -DEXAMPLES=OFF
  -DCLANG_FORMAT=OFF
  -DCLANG_TIDY=OFF
  -DCOVERAGE=OFF
  -DASAN=OFF
  -DLSAN=OFF
  -DMSAN=OFF
  -DTSAN=OFF
  -DUBSAN=OFF
  -DMETRICS_ENABLED=OFF
  -DSQLITE_ENABLED=OFF
  -DLIBP2P_ENABLE_QUIC=OFF
)

if ((verbose)); then
  printf '==> cmake %q ' "${cmake_args[@]}"
  printf '\n'
fi

cmake "${cmake_args[@]}"

if ((configure_only)); then
  exit 0
fi

if ((verbose)); then
  cmake --build "${build_root}"
else
  cmake --build "${build_root}" >/dev/null
fi
