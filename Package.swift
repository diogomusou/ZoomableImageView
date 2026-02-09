// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ZoomableImageView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ZoomableImageView",
            targets: ["ZoomableImageView"]
        ),
    ],
    targets: [
        .target(
            name: "ZoomableImageView"
        ),
    ]
)
