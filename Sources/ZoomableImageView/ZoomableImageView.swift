import Foundation
import SwiftUI
import UIKit

public struct ZoomableImageView: View {
    let image: UIImage
    let maximumZoomScale: CGFloat

    public init(image: UIImage, maximumZoomScale: CGFloat = 5) {
        self.image = image
        self.maximumZoomScale = maximumZoomScale
    }

    public var body: some View {
        ZoomableImageViewRepresentable(image: image, maximumZoomScale: maximumZoomScale)
    }
}

private class LayoutAwareScrollView: UIScrollView {
    var onLayoutChange: ((_ oldSize: CGSize, _ newSize: CGSize) -> Void)?
    private var lastSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastSize {
            let oldSize = lastSize
            lastSize = bounds.size
            onLayoutChange?(oldSize, bounds.size)
        }
    }
}

private struct ZoomableImageViewRepresentable: UIViewRepresentable {
    let image: UIImage
    let maximumZoomScale: CGFloat

    func makeUIView(context: Context) -> LayoutAwareScrollView {
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

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        // Double tap gesture to zoom in/out
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        scrollView.onLayoutChange = { [weak scrollView] oldSize, newSize in
            guard let scrollView = scrollView,
                  let imageView = scrollView.subviews.first as? UIImageView,
                  let image = imageView.image else { return }

            let scrollSize = newSize
            guard scrollSize.width > 0, scrollSize.height > 0 else { return }

            let isInitialLayout = oldSize == .zero

            // Capture the current center point in image coordinates (before changes)
            let oldZoomScale = scrollView.zoomScale
            let oldOffset = scrollView.contentOffset

            // The visible center in content (zoomed) coordinates
            let visibleCenterInContentX = oldOffset.x + oldSize.width / 2
            let visibleCenterInContentY = oldOffset.y + oldSize.height / 2

            // Convert to original image coordinates
            let imageCenterX = visibleCenterInContentX / oldZoomScale
            let imageCenterY = visibleCenterInContentY / oldZoomScale

            let minScale = min(
                scrollSize.width / image.size.width,
                scrollSize.height / image.size.height
            )

            let wasAtMin = abs(scrollView.zoomScale - scrollView.minimumZoomScale) < 0.01
            scrollView.minimumZoomScale = minScale

            if wasAtMin {
                scrollView.zoomScale = minScale
            }

            // Calculate new image size (don't rely on frame which may not be updated yet)
            let newZoomScale = scrollView.zoomScale
            let newImageSize = CGSize(
                width: image.size.width * newZoomScale,
                height: image.size.height * newZoomScale
            )

            // Calculate new insets
            let horizontalInset = max(0, (scrollSize.width - newImageSize.width) / 2)
            let verticalInset = max(0, (scrollSize.height - newImageSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: 0, right: 0)

            // Restore center point (only if was zoomed in and not initial layout)
            if !wasAtMin && !isInitialLayout {
                // Convert image point back to content coordinates and calculate offset
                var newOffsetX = imageCenterX * newZoomScale - scrollSize.width / 2
                var newOffsetY = imageCenterY * newZoomScale - scrollSize.height / 2

                scrollView.contentOffset = CGPoint(x: newOffsetX, y: newOffsetY)
            }
        }

        return scrollView
    }

    func updateUIView(_ scrollView: LayoutAwareScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        if imageView.image == nil {
            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size
            // Layout will be handled by onLayoutChange when bounds are set
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func centerImage(in scrollView: UIScrollView, imageView: UIImageView) {
        let scrollSize = scrollView.bounds.size
        let imageSize = imageView.frame.size
        let horizontalInset = max(0, (scrollSize.width - imageSize.width) / 2)
        let verticalInset = max(0, (scrollSize.height - imageSize.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: verticalInset, left: horizontalInset, bottom: 0, right: 0)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageViewRepresentable
        weak var imageView: UIImageView?

        init(_ parent: ZoomableImageViewRepresentable) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if let imageView = imageView {
                parent.centerImage(in: scrollView, imageView: imageView)
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                // Zoom out
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // Zoom in
                let tapPoint = gesture.location(in: imageView)
                let fillScale = max(
                    scrollView.bounds.size.width / (imageView?.bounds.size.width ?? 1),
                    scrollView.bounds.size.height / (imageView?.bounds.size.height ?? 1)
                )
                let newZoomScale = max(fillScale, scrollView.minimumZoomScale)

                let scrollSize = scrollView.bounds.size
                let width = scrollSize.width / newZoomScale
                let height = scrollSize.height / newZoomScale
                let x = tapPoint.x - (width / 2)
                let y = tapPoint.y - (height / 2)

                let zoomRect = CGRect(x: x, y: y, width: width, height: height)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}
