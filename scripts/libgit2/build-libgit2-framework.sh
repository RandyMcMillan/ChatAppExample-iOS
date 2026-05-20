# Build libgit2 XCFramework
#
# This script assumes that
#  1. it is run at the root of the repo
#  2. the required tools (wget, ninja, cmake, autotools) are installed either globally via homebrew or locally in tools/bin using our other script build_tools.sh
#

export REPO_ROOT=`pwd`
export PATH=$PATH:$REPO_ROOT/tools/bin
export PROJECT_ROOT=$REPO_ROOT/LibGit2-iOS
export INSTALL_ROOT=$PROJECT_ROOT/install
export VERIFY_ROOT=$PROJECT_ROOT/verification
FORCE=0
VERIFY_ONLY=0

while [ $# -gt 0 ]; do
	case "$1" in
		--force|-f)
			FORCE=1
			;;
		--verify)
			VERIFY_ONLY=1
			;;
		*)
			echo "Usage: $0 [--force|-f] [--verify]"
			exit 1
			;;
	esac
	shift
done

function reset_source_tree() {
	local source_dir=$1
	if [ $FORCE -eq 1 ]; then
		rm -rf "$PROJECT_ROOT/$source_dir"
	fi
}

function ensure_tarball() {
	local tarball=$1
	local url=$2
	if [ $FORCE -eq 1 ]; then
		local tmp_tarball="$PROJECT_ROOT/$tarball.tmp"
		rm -f "$tmp_tarball"
		(cd "$PROJECT_ROOT" && curl -fL -s -o "$tarball.tmp" "$url") && mv "$tmp_tarball" "$PROJECT_ROOT/$tarball"
		return
	fi
	test -f "$PROJECT_ROOT/$tarball" || (cd "$PROJECT_ROOT" && curl -LO -s "$url")
}

function ensure_zip_source() {
	local zipfile=$1
	local url=$2
	if [ $FORCE -eq 1 ]; then
		local tmp_zipfile="$PROJECT_ROOT/$zipfile.tmp"
		rm -f "$tmp_zipfile"
		(cd "$PROJECT_ROOT" && curl -fL -s -o "$zipfile.tmp" "$url") && mv "$tmp_zipfile" "$PROJECT_ROOT/$zipfile"
		return
	fi
	test -f "$PROJECT_ROOT/$zipfile" || (cd "$PROJECT_ROOT" && curl -LO -s "$url")
}

function ensure_unpacked_tarball() {
	local source_dir=$1
	local tarball=$2
	local url=$3
	ensure_tarball "$tarball" "$url"
	if [ ! -d "$PROJECT_ROOT/$source_dir" ]; then
		cd "$PROJECT_ROOT" && tar xzf "$tarball"
	fi
}

function ensure_unpacked_zip() {
	local source_dir=$1
	local zipfile=$2
	local url=$3
	ensure_zip_source "$zipfile" "$url"
	if [ ! -d "$PROJECT_ROOT/$source_dir" ]; then
		cd "$PROJECT_ROOT" && ditto -V -x -k --sequesterRsrc --rsrc "$zipfile" ./
	fi
}

function ensure_libgit2_bundled_pcre() {
	mkdir -p "$PROJECT_ROOT/libgit2-1.3.1/deps"
	if [ $FORCE -eq 1 ]; then
		rm -f "$PROJECT_ROOT/libgit2-1.3.1/deps/pcre"
	fi
	if [ ! -e "$PROJECT_ROOT/libgit2-1.3.1/deps/pcre" ]; then
		ln -s ../../pcre-8.45 "$PROJECT_ROOT/libgit2-1.3.1/deps/pcre"
	fi
}

function verify_sha256() {
	local checksum_file=$1
	local archive=$2
	cd "$PROJECT_ROOT" && shasum -a 256 -c "$VERIFY_ROOT/$checksum_file"
}

function verify_libssh2_signature() {
	local archive=$1
	local sigfile=$2
	local keyfile=$3
	local gnupghome
	gnupghome=$(mktemp -d)
	gpg --homedir "$gnupghome" --batch --import "$VERIFY_ROOT/$keyfile" >/dev/null 2>/dev/null
	gpg --homedir "$gnupghome" --batch --verify "$VERIFY_ROOT/$sigfile" "$PROJECT_ROOT/$archive" >/dev/null 2>/dev/null
	rm -rf "$gnupghome"
}

function verify_downloads() {
	ensure_tarball openssl-3.0.4.tar.gz https://www.openssl.org/source/openssl-3.0.4.tar.gz
	verify_sha256 openssl-3.0.4.tar.gz.sha256 openssl-3.0.4.tar.gz

	ensure_tarball libssh2-1.10.0.tar.gz https://www.libssh2.org/download/libssh2-1.10.0.tar.gz
	verify_libssh2_signature libssh2-1.10.0.tar.gz libssh2-1.10.0.tar.gz.asc libssh2-1.10.0.pub

	ensure_zip_source v1.3.1.zip https://github.com/libgit2/libgit2/archive/refs/tags/v1.3.1.zip
	verify_sha256 v1.3.1.zip.sha256 v1.3.1.zip
}

# List of platforms-architecture that we support
# Note that there are limitations in `xcodebuild` command that disallows `maccatalyst` and `macosx` (native macOS lib) in the same xcframework.
AVAILABLE_PLATFORMS=(iphoneos iphonesimulator iphonesimulator-arm64 maccatalyst maccatalyst-arm64) # macosx macosx-arm64

# List of frameworks included in the XCFramework (= AVAILABLE_PLATFORMS without architecture specifications)
XCFRAMEWORK_PLATFORMS=(iphoneos iphonesimulator maccatalyst)

# List of platforms that need to be merged using lipo due to presence of multiple architectures
LIPO_PLATFORMS=(iphonesimulator maccatalyst)

### Setup common environment variables to run CMake for a given platform
### Usage:      setup_variables PLATFORM
### where PLATFORM is the platform to build for and should be one of
###    iphoneos  (implicitly arm64)
###    iphonesimulator, iphonesimulator-arm64
###    maccatalyst, maccatalyst-arm64
###    macosx, macosx-arm64
###
### After this function is executed, the variables
###    $PLATFORM
###    $ARCH
###    $SYSROOT
###    $CMAKE_ARGS
### providing basic/common CMake options will be set.
function setup_variables() {
	cd $PROJECT_ROOT
	PLATFORM=$1

	CMAKE_ARGS=(-DBUILD_SHARED_LIBS=NO \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER_WORKS=ON \
		-DCMAKE_CXX_COMPILER_WORKS=ON \
		-DCMAKE_INSTALL_PREFIX=$INSTALL_ROOT/$PLATFORM)

	case $PLATFORM in
		"iphoneos")
			ARCH=arm64
			SYSROOT=`xcodebuild -version -sdk iphoneos Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH \
				-DCMAKE_OSX_SYSROOT=$SYSROOT);;

		"iphonesimulator")
			ARCH=x86_64
			SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_OSX_SYSROOT=$SYSROOT);;

		"iphonesimulator-arm64")
			ARCH=arm64
			SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH -DCMAKE_OSX_SYSROOT=$SYSROOT);;

		"maccatalyst")
			ARCH=x86_64
			SYSROOT=`xcodebuild -version -sdk macosx Path`
			CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi);;

		"maccatalyst-arm64")
			ARCH=arm64
			SYSROOT=`xcodebuild -version -sdk macosx Path`
			CMAKE_ARGS+=(-DCMAKE_C_FLAGS=-target\ $ARCH-apple-ios14.1-macabi);;

		"macosx")
			ARCH=x86_64
			SYSROOT=`xcodebuild -version -sdk macosx Path`;;

		"macosx-arm64")
			ARCH=arm64
			SYSROOT=`xcodebuild -version -sdk macosx Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH);;

		*)
			echo "Unsupported or missing platform! Must be one of" ${AVAILABLE_PLATFORMS[@]}
			exit 1;;
	esac
}

### Build libpcre for a given platform
function build_libpcre() {
	setup_variables $1

	reset_source_tree pcre-8.45
	if [ ! -d pcre-8.45 ]; then
		git clone https://github.com/light-tech/PCRE.git pcre-8.45
	fi
	cd pcre-8.45

	rm -rf build && mkdir build && cd build
	CMAKE_ARGS+=(-DPCRE_BUILD_PCRECPP=NO \
		-DPCRE_BUILD_PCREGREP=NO \
		-DPCRE_BUILD_TESTS=NO \
		-DPCRE_SUPPORT_LIBBZ2=NO)

	cmake "${CMAKE_ARGS[@]}" .. >/dev/null 2>/dev/null

	cmake --build . --target install >/dev/null 2>/dev/null
}

### Build openssl for a given platform
function build_openssl() {
	setup_variables $1

	reset_source_tree openssl-3.0.4
	ensure_tarball openssl-3.0.4.tar.gz https://www.openssl.org/source/openssl-3.0.4.tar.gz
	verify_sha256 openssl-3.0.4.tar.gz.sha256 openssl-3.0.4.tar.gz
	ensure_unpacked_tarball openssl-3.0.4 openssl-3.0.4.tar.gz https://www.openssl.org/source/openssl-3.0.4.tar.gz
	cd openssl-3.0.4

	case $PLATFORM in
		"iphoneos")
			TARGET_OS=ios64-cross
			export CFLAGS="-isysroot $SYSROOT -arch $ARCH";;

		"iphonesimulator"|"iphonesimulator-arm64")
			TARGET_OS=iossimulator-xcrun
			export CFLAGS="-isysroot $SYSROOT -arch $ARCH";;

		"maccatalyst"|"maccatalyst-arm64")
			TARGET_OS=darwin64-$ARCH-cc
			export CFLAGS="-isysroot $SYSROOT -target $ARCH-apple-ios14.1-macabi";;

		"macosx"|"macosx-arm64")
			TARGET_OS=darwin64-$ARCH-cc
			export CFLAGS="-isysroot $SYSROOT";;

		*)
			echo "Unsupported or missing platform!";;
	esac

	# See https://wiki.openssl.org/index.php/Compilation_and_Installation
	./Configure --prefix=$INSTALL_ROOT/$PLATFORM \
		--openssldir=$INSTALL_ROOT/$PLATFORM \
		$TARGET_OS no-shared no-dso no-hw no-engine >/dev/null 2>/dev/null

	make >/dev/null 2>/dev/null
	make install_sw install_ssldirs >/dev/null 2>/dev/null
	export -n CFLAGS
}

### Build libssh2 for a given platform (assume openssl was built)
function build_libssh2() {
	setup_variables $1

	reset_source_tree libssh2-1.10.0
	ensure_tarball libssh2-1.10.0.tar.gz https://www.libssh2.org/download/libssh2-1.10.0.tar.gz
	verify_libssh2_signature libssh2-1.10.0.tar.gz libssh2-1.10.0.tar.gz.asc libssh2-1.10.0.pub
	ensure_unpacked_tarball libssh2-1.10.0 libssh2-1.10.0.tar.gz https://www.libssh2.org/download/libssh2-1.10.0.tar.gz
	cd libssh2-1.10.0

	rm -rf build && mkdir build && cd build

	CMAKE_ARGS+=(-DCRYPTO_BACKEND=OpenSSL \
		-DOPENSSL_ROOT_DIR=$INSTALL_ROOT/$PLATFORM \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_TESTING=OFF)

	cmake "${CMAKE_ARGS[@]}" .. >/dev/null 2>/dev/null

	cmake --build . --target install >/dev/null 2>/dev/null
}

### Build libgit2 for a single platform (given as the first and only argument)
### See @setup_variables for the list of available platform names
### Assume openssl and libssh2 was built
function build_libgit2() {
    setup_variables $1

    reset_source_tree libgit2-1.3.1
    ensure_zip_source v1.3.1.zip https://github.com/libgit2/libgit2/archive/refs/tags/v1.3.1.zip
    verify_sha256 v1.3.1.zip.sha256 v1.3.1.zip
    ensure_unpacked_zip libgit2-1.3.1 v1.3.1.zip https://github.com/libgit2/libgit2/archive/refs/tags/v1.3.1.zip
    ensure_libgit2_bundled_pcre
    cd libgit2-1.3.1

    rm -rf build && mkdir build && cd build

    CMAKE_ARGS+=(-DBUILD_CLAR=NO)

    # See libgit2/cmake/FindPkgLibraries.cmake to understand how libgit2 looks for libssh2
    # Basically, setting LIBSSH2_FOUND forces SSH support and since we are building static library,
    # we only need the headers.
    CMAKE_ARGS+=(-DOPENSSL_ROOT_DIR=$INSTALL_ROOT/$PLATFORM \
        -DUSE_SSH=ON \
        -DLIBSSH2_FOUND=YES \
        -DLIBSSH2_INCLUDE_DIRS=$INSTALL_ROOT/$PLATFORM/include)

    cmake "${CMAKE_ARGS[@]}" .. #>/dev/null 2>/dev/null

    cmake --build . --target install #>/dev/null 2>/dev/null
}

### Create xcframework for a given library
function build_xcframework() {
	local FWNAME=$1
	shift
	local PLATFORMS=( "$@" )
	local FRAMEWORKS_ARGS=()

	echo "Building" $FWNAME "XCFramework containing" ${PLATFORMS[@]}

	for p in ${PLATFORMS[@]}; do
		FRAMEWORKS_ARGS+=("-library" "$INSTALL_ROOT/$p/$FWNAME.a" "-headers" "$INSTALL_ROOT/$p/include")
	done

	cd $PROJECT_ROOT
	xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output $FWNAME.xcframework
}

### Copy SwiftGit2's module.modulemap to libgit2.xcframework/*/Headers
### so that we can use libgit2 C API in Swift (e.g. via SwiftGit2)
function copy_modulemap() {
    cd $PROJECT_ROOT
    local FWDIRS=$(find Clibgit2.xcframework -mindepth 1 -maxdepth 1 -type d)
    for d in ${FWDIRS[@]}; do
        echo $d
        cp Clibgit2_modulemap $d/Headers/module.modulemap
    done
}

### Build libgit2 and Clibgit2 frameworks for all available platforms

if [ $VERIFY_ONLY -eq 1 ]; then
	verify_downloads
	exit 0
fi

for p in ${AVAILABLE_PLATFORMS[@]}; do
	echo "Build libraries for $p"
	build_libpcre $p
	build_openssl $p
	build_libssh2 $p
	build_libgit2 $p

	# Merge all static libs as libgit2.a since xcodebuild doesn't allow specifying multiple .a
	cd $INSTALL_ROOT/$p
	libtool -static -o libgit2.a lib/*.a
done

# Merge the libgit2.a for iphonesimulator & iphonesimulator-arm64 as well as maccatalyst & maccatalyst-arm64 using lipo
for p in ${LIPO_PLATFORMS[@]}; do
    cd $INSTALL_ROOT/$p
    lipo libgit2.a ../$p-arm64/libgit2.a -output libgit2_all_archs.a -create
    test -f libgit2_all_archs.a && rm libgit2.a && mv libgit2_all_archs.a libgit2.a
done

# Build raw libgit2 XCFramework for Objective-C usage
build_xcframework libgit2 ${XCFRAMEWORK_PLATFORMS[@]}
zip -r libgit2.xcframework.zip -i libgit2.xcframework/

# Build Clibgit2 XCFramework for use with SwiftGit2
mv libgit2.xcframework Clibgit2.xcframework
copy_modulemap
zip -r Clibgit2.xcframework.zip -i Clibgit2.xcframework/
