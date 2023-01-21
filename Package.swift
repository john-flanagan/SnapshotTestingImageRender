// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SnapshotTestingImageRender",
  platforms: [
    .iOS(.v16),
    .tvOS(.v16),
  ],
  products: [
    .library(name: "SnapshotTestingImageRender", targets: ["SnapshotTestingImageRender"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.10.0"),
  ],
  targets: [
    .target(
      name: "SnapshotTestingImageRender",
      dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ]
    ),
    .testTarget(
      name: "SnapshotTestingImageRenderTests",
      dependencies: [
        "SnapshotTestingImageRender",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      exclude: [
        "__Snapshots__",
      ]
    ),
  ]
)
