#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${script_dir}/../LibP2P-iOS/scripts/build-libp2p-framework.sh" "$@"
