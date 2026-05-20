#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"
source_root="${project_root}/cpp-libp2p-0.1.37"
build_root="${project_root}/build"
install_root="${project_root}/install"
xcframework_root="${project_root}/LibP2P.xcframework"
xcframework_zip="${project_root}/LibP2P.xcframework.zip"
modulemap_source="${project_root}/LibP2P_modulemap"

AVAILABLE_PLATFORMS=(iphoneos iphonesimulator iphonesimulator-arm64 maccatalyst maccatalyst-arm64)
XCFRAMEWORK_PLATFORMS=(iphoneos iphonesimulator maccatalyst)
LIPO_PLATFORMS=(iphonesimulator maccatalyst)

FORCE=0
VERBOSE=0
PACKAGE_ONLY=0

usage() {
  cat <<EOF
usage: $(basename "$0") [--force] [--verbose] [--package-only]

Build LibP2P.xcframework from the vendored cpp-libp2p source tree.

The default build disables QUIC so the build can start without lsquic.
EOF
}

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --force|-f)
      FORCE=1
      ;;
    --verbose|-v)
      VERBOSE=1
      ;;
    --package-only)
      PACKAGE_ONLY=1
      ;;
    *)
      echo "usage: $(basename "$0") [--force] [--verbose] [--package-only]" >&2
      exit 1
      ;;
  esac
  shift
done

run_cmd() {
  if ((VERBOSE)); then
    "$@"
  else
    "$@" >/dev/null
  fi
}

setup_variables() {
  PLATFORM="$1"
  CMAKE_ARGS=(
    -DBUILD_SHARED_LIBS=OFF
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER_WORKS=ON
    -DCMAKE_CXX_COMPILER_WORKS=ON
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    -DCMAKE_INSTALL_PREFIX="${install_root}/${PLATFORM}"
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
    -DEXPOSE_MOCKS=OFF
    -DMETRICS_ENABLED=OFF
    -DSQLITE_ENABLED=OFF
    -DLIBP2P_ENABLE_QUIC=OFF
  )

  case "${PLATFORM}" in
    iphoneos)
      ARCH=arm64
      SYSROOT="$(xcodebuild -version -sdk iphoneos Path)"
      CMAKE_ARGS+=(
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
        -DCMAKE_OSX_SYSROOT="${SYSROOT}"
      )
      ;;
    iphonesimulator)
      ARCH=x86_64
      SYSROOT="$(xcodebuild -version -sdk iphonesimulator Path)"
      CMAKE_ARGS+=(
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
        -DCMAKE_OSX_SYSROOT="${SYSROOT}"
      )
      ;;
    iphonesimulator-arm64)
      ARCH=arm64
      SYSROOT="$(xcodebuild -version -sdk iphonesimulator Path)"
      CMAKE_ARGS+=(
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
        -DCMAKE_OSX_SYSROOT="${SYSROOT}"
      )
      ;;
    maccatalyst)
      ARCH=x86_64
      SYSROOT="$(xcodebuild -version -sdk macosx Path)"
      CMAKE_ARGS+=(
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
        -DCMAKE_OSX_SYSROOT="${SYSROOT}"
        -DCMAKE_C_FLAGS=-target\ ${ARCH}-apple-ios14.1-macabi
        -DCMAKE_CXX_FLAGS=-target\ ${ARCH}-apple-ios14.1-macabi
      )
      ;;
    maccatalyst-arm64)
      ARCH=arm64
      SYSROOT="$(xcodebuild -version -sdk macosx Path)"
      CMAKE_ARGS+=(
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}"
        -DCMAKE_OSX_SYSROOT="${SYSROOT}"
        -DCMAKE_C_FLAGS=-target\ ${ARCH}-apple-ios14.1-macabi
        -DCMAKE_CXX_FLAGS=-target\ ${ARCH}-apple-ios14.1-macabi
      )
      ;;
    *)
      echo "Unsupported platform: ${PLATFORM}" >&2
      exit 1
      ;;
  esac
}

build_platform() {
  setup_variables "$1"

  local platform_build_root="${build_root}/${PLATFORM}"
  local platform_install_root="${install_root}/${PLATFORM}"

  if ((FORCE)); then
    rm -rf "${platform_build_root}" "${platform_install_root}"
  fi

  mkdir -p "${platform_build_root}" "${platform_install_root}"

  run_cmd cmake -S "${source_root}" -B "${platform_build_root}" "${CMAKE_ARGS[@]}"
  run_cmd cmake --build "${platform_build_root}" --target install

  if [[ -d "${platform_install_root}/lib" ]]; then
    (cd "${platform_install_root}" && run_cmd libtool -static -o libp2p.a lib/*.a)
  else
    printf 'missing install lib directory for %s\n' "${PLATFORM}" >&2
    exit 1
  fi
}

merge_platform_arches() {
  local platform="$1"
  local primary="$2"
  local secondary="$3"
  local platform_install_root="${install_root}/${platform}"

  (cd "${platform_install_root}" && \
    run_cmd lipo libp2p.a "../${secondary}/libp2p.a" -output libp2p_all_archs.a -create && \
    rm -f libp2p.a && \
    mv libp2p_all_archs.a libp2p.a)
}

copy_modulemap() {
  local headers
  while IFS= read -r headers; do
    cp "${modulemap_source}" "${headers}/module.modulemap"
  done < <(find "${xcframework_root}" -type d -name Headers)
}

build_xcframework() {
  local framework_args=()
  local platform

  for platform in "${XCFRAMEWORK_PLATFORMS[@]}"; do
    framework_args+=(
      -library "${install_root}/${platform}/libp2p.a"
      -headers "${install_root}/${platform}/include"
    )
  done

  rm -rf "${xcframework_root}" "${xcframework_zip}"
  run_cmd xcodebuild -create-xcframework "${framework_args[@]}" -output "${xcframework_root}"
  copy_modulemap
  run_cmd zip -r "${xcframework_zip}" "${xcframework_root##*/}"
}

if (( ! PACKAGE_ONLY )); then
  for platform in "${AVAILABLE_PLATFORMS[@]}"; do
    build_platform "${platform}"
  done

  merge_platform_arches iphonesimulator x86_64 iphonesimulator-arm64
  merge_platform_arches maccatalyst x86_64 maccatalyst-arm64
fi

build_xcframework
