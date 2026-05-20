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
        .binaryTarget(
            name: "LibP2P",
            path: "LibP2P.xcframework"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
