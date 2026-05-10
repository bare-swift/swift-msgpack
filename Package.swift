// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import PackageDescription

let package = Package(
    name: "swift-msgpack",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MsgPack", targets: ["MsgPack"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
        .package(url: "https://github.com/bare-swift/swift-bytes.git", from: "0.1.0"),
        .package(url: "https://github.com/bare-swift/swift-time.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "MsgPack",
            dependencies: [
                .product(name: "Bytes", package: "swift-bytes"),
                .product(name: "Time", package: "swift-time")
            ]
        ),
        .testTarget(
            name: "MsgPackTests",
            dependencies: ["MsgPack"]
        )
    ]
)
