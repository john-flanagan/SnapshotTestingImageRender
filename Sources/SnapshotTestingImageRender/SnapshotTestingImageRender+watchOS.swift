#if os(watchOS)
import SnapshotTesting
import SwiftUI
import XCTest

extension Snapshotting where Value: SwiftUI.View, Format == UIImage {
  
  /// A snapshot strategy for comparing SwiftUI Views based on pixel equality using watchOS 9 `ImageRenderer`.
  ///
  /// `ImageRenderer` output only includes views that SwiftUI renders, such as text, images, shapes,
  /// and composite views of these types. It does not render views provided by native platform
  /// frameworks (AppKit and UIKit) such as web views, media players, and some controls. For these
  /// views, `ImageRenderer` displays a placeholder image, similar to the behavior of
  /// `drawingGroup(opaque:colorMode:)`.
  ///
  /// - Parameters:
  ///   - precision: The percentage of pixels that must match.
  ///   - layout: A view layout override.
  ///   - proposedSize: The size proposed to the view. See ``SwiftUI/ImageRenderer/proposedSize``.
  public static func imageRender(
    precision: Float = 1,
    layout: SwiftUISnapshotLayout = .sizeThatFits,
    proposedSize: ProposedViewSize? = nil
  )
  -> Snapshotting {
    let scale = 1.0
    
    return SimplySnapshotting(
      pathExtension: "png",
      diffing: .init(toData: { value in
        value.pngData()!
      }, fromData: { data in
        UIImage(data: data)!
      }, diff: Diffing.image(precision: precision, scale: scale).diff)
    ).asyncPullback { view in
      return .init { callback in
        Task { @MainActor in
          let renderer = ImageRenderer(
            content: SnapshottingView(layout: layout, content: view)
          )
          renderer.proposedSize = proposedSize ?? ProposedViewSize(WKApplication.shared().rootInterfaceController?.contentFrame.size ?? CGSize(width: 320, height: 320))
          renderer.scale = scale
          
          callback(renderer.uiImage ?? UIImage())
        }
      }
    }
  }
}

private struct SnapshottingView<Content: SwiftUI.View>: SwiftUI.View {
  let layout: SwiftUISnapshotLayout
  let content: Content
  
  var body: some SwiftUI.View {
    Group {
      switch layout {
      case let .fixed(width, height):
        content
          .frame(width: width, height: height)
        
      case .sizeThatFits:
        content
      }
    }
    .background(Color.black)
  }
}

// Taken from the 'parent' library 'SnapshotTesting' but with the `perceptualPrecision` functionality removed
extension Diffing where Value == UIImage {
  /// A pixel-diffing strategy for UIImage's which requires a 100% match.
  public static let image = Diffing.image()
  
  /// A pixel-diffing strategy for UIImage that allows customizing how precise the matching must be.
  ///
  /// - Parameters:
  ///   - precision: The percentage of pixels that must match.
  ///   - scale: Scale to use when loading the reference image from disk.
  /// - Returns: A new diffing strategy.
  public static func image(precision: Float = 1, scale: CGFloat = 1.0) -> Diffing {
    let imageScale: CGFloat = scale
    return Diffing(
      toData: { $0.pngData()! },
      fromData: { UIImage(data: $0, scale: imageScale)! }
    ) { old, new -> (String, [XCTAttachment])? in
      guard let message = compare(old, new, precision: precision) else { return nil }
      let difference = SnapshotTestingImageRender.diff(old, new)
      let oldAttachment = XCTAttachment(image: old)
      oldAttachment.name = "reference"
      let isEmptyImage = new.size == .zero
      let newAttachment: XCTAttachment
      if isEmptyImage {
        newAttachment = XCTAttachment(string: "The image is empty")
      } else {
        newAttachment = XCTAttachment(image: new)
      }
      newAttachment.name = "failure"
      let differenceAttachment = XCTAttachment(image: difference)
      differenceAttachment.name = "difference"
      return (
        message,
        [oldAttachment, newAttachment, differenceAttachment]
      )
    }
  }
  
}

// remap snapshot & reference to same colorspace
private let imageContextColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
private let imageContextBitsPerComponent = 8
private let imageContextBytesPerPixel = 4

private func compare(_ old: UIImage, _ new: UIImage, precision: Float) -> String? {
  guard let oldCgImage = old.cgImage else {
    return "Reference image could not be loaded."
  }
  guard let newCgImage = new.cgImage else {
    return "Newly-taken snapshot could not be loaded."
  }
  guard newCgImage.width != 0, newCgImage.height != 0 else {
    return "Newly-taken snapshot is empty."
  }
  guard oldCgImage.width == newCgImage.width, oldCgImage.height == newCgImage.height else {
    return "Newly-taken snapshot@\(new.size) does not match reference@\(old.size)."
  }
  let pixelCount = oldCgImage.width * oldCgImage.height
  let byteCount = imageContextBytesPerPixel * pixelCount
  var oldBytes = [UInt8](repeating: 0, count: byteCount)
  guard let oldData = context(for: oldCgImage, data: &oldBytes)?.data else {
    return "Reference image's data could not be loaded."
  }
  if let newContext = context(for: newCgImage), let newData = newContext.data {
    if memcmp(oldData, newData, byteCount) == 0 { return nil }
  }
  var newerBytes = [UInt8](repeating: 0, count: byteCount)
  guard
    let pngData = new.pngData(),
    let newerCgImage = UIImage(data: pngData)?.cgImage,
    let newerContext = context(for: newerCgImage, data: &newerBytes),
    let newerData = newerContext.data
  else {
    return "Newly-taken snapshot's data could not be loaded."
  }
  if memcmp(oldData, newerData, byteCount) == 0 { return nil }
  if precision >= 1 {
    return "Newly-taken snapshot does not match reference."
  }
  let byteCountThreshold = Int((1 - precision) * Float(byteCount))
  var differentByteCount = 0
  for offset in 0..<byteCount {
    if oldBytes[offset] != newerBytes[offset] {
      differentByteCount += 1
    }
  }
  if differentByteCount > byteCountThreshold {
    let actualPrecision = 1 - Float(differentByteCount) / Float(byteCount)
    return "Actual image precision \(actualPrecision) is less than required \(precision)"
  }
  return nil
}

private func context(for cgImage: CGImage, data: UnsafeMutableRawPointer? = nil) -> CGContext? {
  let bytesPerRow = cgImage.width * imageContextBytesPerPixel
  guard
    let colorSpace = imageContextColorSpace,
    let context = CGContext(
      data: data,
      width: cgImage.width,
      height: cgImage.height,
      bitsPerComponent: imageContextBitsPerComponent,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else { return nil }
  
  context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
  return context
}

private func diff(_ old: UIImage, _ new: UIImage) -> UIImage {
  let width = max(old.size.width, new.size.width)
  let height = max(old.size.height, new.size.height)
  let scale = max(old.scale, new.scale)
  UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, scale)
  new.draw(at: .zero)
  old.draw(at: .zero, blendMode: .difference, alpha: 1)
  let differenceImage = UIGraphicsGetImageFromCurrentImageContext()!
  UIGraphicsEndImageContext()
  return differenceImage
}
#endif
