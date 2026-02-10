//
//  ZoomableImageView.swift
//  ZoomableImageView
//
//  Created by Diogo Musou on 2026.
//  Licensed under MIT License.
//

import SwiftUI
import UIKit

// MARK: - Public API

/// A SwiftUI view that displays an image with smooth zoom and pan gestures,
/// similar to Apple's Photos app.
///
/// `ZoomableImageView` supports:
/// - Pinch to zoom with configurable maximum scale
/// - Double tap to zoom in/out
/// - Pan gestures while zoomed
/// - Automatic centering when the image is smaller than the viewport
/// - Seamless device rotation that preserves the visible center point
///
/// ## Usage
/// ```swift
/// ZoomableImageView(image: UIImage(named: "photo")!)
/// ZoomableImageView(image: myImage, maximumZoomScale: 10)
/// ```
public struct ZoomableImageView: View {
    private let image: UIImage
    private let maximumZoomScale: CGFloat

    /// Creates a zoomable image view.
    /// - Parameters:
    ///   - image: The image to display.
    ///   - maximumZoomScale: The maximum zoom scale allowed. Defaults to 5.
    public init(image: UIImage, maximumZoomScale: CGFloat = 5) {
        self.image = image
        self.maximumZoomScale = maximumZoomScale
    }

    public var body: some View {
        ZoomableScrollView(image: image, maximumZoomScale: maximumZoomScale)
    }
}

// MARK: - Layout-Aware Scroll View

/// A custom scroll view that notifies when its layout changes.
/// Used to detect device rotation and size changes.
private final class LayoutAwareScrollView: UIScrollView {
    var onLayoutChange: ((_ oldSize: CGSize, _ newSize: CGSize) -> Void)?
    private var previousSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != previousSize else { return }

        let oldSize = previousSize
        previousSize = bounds.size
        onLayoutChange?(oldSize, bounds.size)
    }
}

// MARK: - UIViewRepresentable Implementation

/// The UIViewRepresentable wrapper that bridges UIScrollView to SwiftUI.
private struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage
    let maximumZoomScale: CGFloat

    func makeUIView(context: Context) -> LayoutAwareScrollView {
        let scrollView = createScrollView(context: context)
        let imageView = createImageView()

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        configureDoubleTapGesture(on: scrollView, context: context)
        configureLayoutHandler(on: scrollView)

        return scrollView
    }

    func updateUIView(_ scrollView: LayoutAwareScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView, imageView.image == nil else { return }

        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(centerImageHandler: centerImage)
    }

    // MARK: - View Creation

    private func createScrollView(context: Context) -> LayoutAwareScrollView {
        let scrollView = LayoutAwareScrollView()
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = maximumZoomScale
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator
        return scrollView
    }

    private func createImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        return imageView
    }

    // MARK: - Gesture Configuration

    private func configureDoubleTapGesture(on scrollView: UIScrollView, context: Context) {
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    // MARK: - Layout Handling

    private func configureLayoutHandler(on scrollView: LayoutAwareScrollView) {
        scrollView.onLayoutChange = { [weak scrollView] oldSize, newSize in
            guard let scrollView = scrollView,
                  let imageView = scrollView.subviews.first as? UIImageView,
                  let image = imageView.image,
                  newSize.width > 0, newSize.height > 0 else { return }

            let isInitialLayout = oldSize == .zero
            let layoutContext = LayoutContext(
                scrollView: scrollView,
                image: image,
                oldSize: oldSize,
                newSize: newSize
            )

            updateZoomScaleForLayout(layoutContext, isInitialLayout: isInitialLayout)
        }
    }

    /// Updates zoom scale and content position when layout changes (e.g., device rotation).
    private func updateZoomScaleForLayout(_ context: LayoutContext, isInitialLayout: Bool) {
        let scrollView = context.scrollView
        let image = context.image
        let newSize = context.newSize

        // Calculate the center point in image coordinates before changes
        let visibleCenter = calculateVisibleCenterInImageCoordinates(context)

        // Update minimum zoom scale to fit the image
        let minScale = min(
            newSize.width / image.size.width,
            newSize.height / image.size.height
        )

        let wasAtMinimumScale = abs(scrollView.zoomScale - scrollView.minimumZoomScale) < 0.01
        scrollView.minimumZoomScale = minScale

        if wasAtMinimumScale {
            scrollView.zoomScale = minScale
        }

        // Update content insets to center the image
        let newImageSize = CGSize(
            width: image.size.width * scrollView.zoomScale,
            height: image.size.height * scrollView.zoomScale
        )
        let horizontalInset = max(0, (newSize.width - newImageSize.width) / 2)
        let verticalInset = max(0, (newSize.height - newImageSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: 0, right: 0)

        // Restore the visible center point when zoomed and rotating
        if !wasAtMinimumScale && !isInitialLayout {
            restoreVisibleCenter(visibleCenter, in: scrollView, viewportSize: newSize)
        }
    }

    private func calculateVisibleCenterInImageCoordinates(_ context: LayoutContext) -> CGPoint {
        let offset = context.scrollView.contentOffset
        let zoomScale = context.scrollView.zoomScale
        let oldSize = context.oldSize

        return CGPoint(
            x: (offset.x + oldSize.width / 2) / zoomScale,
            y: (offset.y + oldSize.height / 2) / zoomScale
        )
    }

    private func restoreVisibleCenter(_ imageCenter: CGPoint, in scrollView: UIScrollView, viewportSize: CGSize) {
        let zoomScale = scrollView.zoomScale
        let newOffset = CGPoint(
            x: imageCenter.x * zoomScale - viewportSize.width / 2,
            y: imageCenter.y * zoomScale - viewportSize.height / 2
        )
        scrollView.contentOffset = newOffset
    }

    // MARK: - Centering

    /// Centers the image within the scroll view by adjusting content insets.
    fileprivate func centerImage(in scrollView: UIScrollView, imageView: UIImageView) {
        let scrollSize = scrollView.bounds.size
        let imageSize = imageView.frame.size
        let horizontalInset = max(0, (scrollSize.width - imageSize.width) / 2)
        let verticalInset = max(0, (scrollSize.height - imageSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: 0, right: 0)
    }
}

// MARK: - Layout Context

/// Encapsulates the context needed for layout calculations.
private struct LayoutContext {
    let scrollView: UIScrollView
    let image: UIImage
    let oldSize: CGSize
    let newSize: CGSize
}

// MARK: - Coordinator

extension ZoomableScrollView {
    /// Coordinator that handles scroll view delegate methods and gestures.
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        private let centerImageHandler: (UIScrollView, UIImageView) -> Void

        init(centerImageHandler: @escaping (UIScrollView, UIImageView) -> Void) {
            self.centerImageHandler = centerImageHandler
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = imageView else { return }
            centerImageHandler(scrollView, imageView)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView,
                  let imageView = imageView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                zoomOut(scrollView)
            } else {
                zoomIn(scrollView, toPoint: gesture.location(in: imageView))
            }
        }

        private func zoomOut(_ scrollView: UIScrollView) {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        }

        private func zoomIn(_ scrollView: UIScrollView, toPoint point: CGPoint) {
            guard let imageView = imageView else { return }

            // Calculate zoom scale to fill the viewport
            let fillScale = max(
                scrollView.bounds.width / imageView.bounds.width,
                scrollView.bounds.height / imageView.bounds.height
            )
            let targetScale = max(fillScale, scrollView.minimumZoomScale)

            // Calculate the rect to zoom to, centered on the tap point
            let zoomRect = calculateZoomRect(
                center: point,
                scale: targetScale,
                in: scrollView
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }

        private func calculateZoomRect(center: CGPoint, scale: CGFloat, in scrollView: UIScrollView) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale
            )
            let origin = CGPoint(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2
            )
            return CGRect(origin: origin, size: size)
        }
    }
}
