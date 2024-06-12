//
//  Package.swift
//  VLC
//
//  Created by Nikhilesh on 12/06/24.
//  Copyright © 2024 VideoLAN. All rights reserved.
//

// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MobileVLCKit",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "MobileVLCKit",
            targets: ["MobileVLCKit"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "MobileVLCKit",
            path: "./path/to/MobileVLCKit.xcframework"
        )
    ]
)
