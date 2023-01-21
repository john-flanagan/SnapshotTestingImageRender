import SnapshotTesting
import SwiftUI

extension Snapshotting where Value: SwiftUI.View, Format == UIImage {

  /// A snapshot strategy for comparing SwiftUI Views based on pixel equality using iOS 16 `ImageRenderer`.
  ///
  /// `ImageRenderer` output only includes views that SwiftUI renders, such as text, images, shapes,
  /// and composite views of these types. It does not render views provided by native platform
  /// frameworks (AppKit and UIKit) such as web views, media players, and some controls. For these
  /// views, `ImageRenderer` displays a placeholder image, similar to the behavior of
  /// `drawingGroup(opaque:colorMode:)`.
  public static var imageRender: Snapshotting {
    return .imageRender()
  }

  /// A snapshot strategy for comparing SwiftUI Views based on pixel equality using iOS 16 `ImageRenderer`.
  ///
  /// `ImageRenderer` output only includes views that SwiftUI renders, such as text, images, shapes,
  /// and composite views of these types. It does not render views provided by native platform
  /// frameworks (AppKit and UIKit) such as web views, media players, and some controls. For these
  /// views, `ImageRenderer` displays a placeholder image, similar to the behavior of
  /// `drawingGroup(opaque:colorMode:)`.
  ///
  /// - Parameters:
  ///   - precision: The percentage of pixels that must match.
  ///   - perceptualPrecision: The percentage a pixel must match the source pixel to be considered a match. [98-99% mimics the precision of the human eye.](http://zschuessler.github.io/DeltaE/learn/#toc-defining-delta-e)
  ///   - layout: A view layout override.
  ///   - proposedSize: The size proposed to the view. See ``SwiftUI/ImageRenderer/proposedSize``.
  ///   - traits: A trait collection override.
  public static func imageRender(
    precision: Float = 1,
    perceptualPrecision: Float = 1,
    layout: SwiftUISnapshotLayout = .sizeThatFits,
    proposedSize: ProposedViewSize? = nil,
    traits: UITraitCollection = .init()
    )
    -> Snapshotting {
      let scale = traits.displayScale != 0.0 ? traits.displayScale : 1
      return SimplySnapshotting.image(precision: precision, perceptualPrecision: perceptualPrecision, scale: scale).asyncPullback { view in
        return .init { callback in
          Task { @MainActor in
            let renderer = ImageRenderer(
              content: SnapshottingView(layout: layout, traits: traits, content: view)
            )
            renderer.proposedSize = proposedSize ?? ProposedViewSize(UIScreen.main.bounds.size)
            renderer.scale = scale

            callback(renderer.uiImage ?? UIImage())
          }
        }
      }
  }
}

private struct SnapshottingView<Content: SwiftUI.View>: SwiftUI.View {
  let layout: SwiftUISnapshotLayout
  let traits: UITraitCollection
  let content: Content

  var body: some SwiftUI.View {
    Group {
      switch layout {
      case let .device(config):
        content
          // Allow content frame to grow so it is not in direct contact with the safe areas
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          // Apply device safe areas
          .safeAreaInset(edge: .top, spacing: 0) { Spacer().frame(height: config.safeArea.top) }
          .safeAreaInset(edge: .bottom, spacing: 0) { Spacer().frame(height: config.safeArea.bottom) }
          .safeAreaInset(edge: .leading, spacing: 0) { Spacer().frame(width: config.safeArea.left) }
          .safeAreaInset(edge: .trailing, spacing: 0) { Spacer().frame(width: config.safeArea.right) }
          // Constrain to device screen dimensions
          .frame(width: config.size?.width, height: config.size?.height)
          // Apply relevant device traits
          .modifier(TraitsModifier(traits: config.traits))

      case let .fixed(width, height):
        content
          .frame(width: width, height: height)

      case .sizeThatFits:
        content
      }
    }
    .background(Color(uiColor: UIColor.systemBackground))
    .modifier(TraitsModifier(traits: traits))
  }
}

private struct TraitsModifier: ViewModifier {
  let traits: UITraitCollection

  func body(content: Content) -> some SwiftUI.View {
    content
      .environment(\.horizontalSizeClass, UserInterfaceSizeClass(traits.horizontalSizeClass))
      .environment(\.verticalSizeClass, UserInterfaceSizeClass(traits.verticalSizeClass))
      .transformEnvironment(\.layoutDirection) { direction in
        direction = LayoutDirection(traits.layoutDirection) ?? direction
      }
      .transformEnvironment(\.dynamicTypeSize) { typeSize in
        typeSize = DynamicTypeSize(traits.preferredContentSizeCategory) ?? typeSize
      }
      .transformEnvironment(\.colorScheme) { colorScheme in
        colorScheme = ColorScheme(traits.userInterfaceStyle) ?? colorScheme
      }
  }
}
