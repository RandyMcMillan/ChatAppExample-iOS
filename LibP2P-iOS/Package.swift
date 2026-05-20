// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "LibP2P-iOS",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "LibP2P",
            targets: ["LibP2P"]
        ),
    ],
    targets: [
        .target(
            name: "LibP2P",
            path: "cpp-libp2p-0.1.37",
            exclude: [
                ".clang-format",
                ".clang-tidy",
                ".githooks",
                ".github",
                ".gitignore",
                ".gitmodules",
                ".lcovrc",
                "CMakeLists.txt",
                "LICENSE-APACHE",
                "LICENSE-MIT",
                "README.md",
                "cmake",
                "codecov.yml",
                "docker-compose.yml",
                "example",
                "housekeeping",
                "test",
            ],
            publicHeadersPath: "include"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
