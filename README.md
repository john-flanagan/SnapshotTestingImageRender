# SnapshotTestingImageRender

A extension to [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing) that adds a SwiftUI snapshot strategy using [`SwiftUI.ImageRender`](https://developer.apple.com/documentation/swiftui/imagerenderer) to snapshot the `View`.

## Usage

Once [installed](#installation), _no additional configuration is required_. You can import the `ImageRenderSnapshotStrategy` module, call into `SnapshotTesting` following their usage guide but provide the `.imageRender` strategy as below.

```swift
import XCTest
import SnapshotTesting
import SnapshotTestingImageRender

class ContentViewTests: XCTestCase {
  func testSnapshots() {
    let view = ContentView()
    assertSnapshot(matching: view, as: .imageRender)
  }
}
```

## Installation

### Xcode 11

> ⚠️ Warning: By default, Xcode will try to add the SnapshotTestingImageRender package to your project's main application/framework target. Please ensure that SnapshotTestingImageRender is added to a _test_ target instead, as documented in the last step, below.
 1. From the **File** menu, navigate through **Swift Packages** and select **Add Package Dependency…**.
 2. Enter package repository URL: `https://github.com/john-flanagan/SnapshotTestingImageRender`
 3. Confirm the version and let Xcode resolve the package
 4. On the final dialog, update SnapshotTestingImageRender's **Add to Target** column to a test target that will contain snapshot tests (if you have more than one test target, you can later add SnapshotTestingImageRender to them by manually linking the library in its build phase)

### Swift Package Manager

If you want to use SnapshotTestingImageRender in any other project that uses [Swift Package Manager](https://swift.org/package-manager/), add the package as a dependency in `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/john-flanagan/SnapshotTestingImageRender.git", from: "1.0.0"),
]
```

Next, add `SnapshotTestingImageRender` as a dependency of your test target:

```swift
targets: [
  .target(
    name: "MyApp"
  ),

  .testTarget(
    name: "MyAppTests",
    dependencies: [
      .target(name: "MyApp"),
      .product(name: "SnapshotTestingImageRender", package: "SnapshotTestingImageRender"),
    ]
  ),
]
```

## License

This library is released under the MIT license. See [LICENSE](LICENSE) for details.

