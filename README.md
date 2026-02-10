# ZoomableImageView

A SwiftUI image view with smooth zoom and pan gestures, delivering an experience similar to Apple's Photos app.

## Features

- **Pinch to Zoom** - Smooth, fluid zoom with configurable maximum scale
- **Double Tap to Zoom** - Tap twice to zoom in on a specific point, tap again to reset
- **Pan While Zoomed** - Freely pan around the image when zoomed in
- **Bounce Effect** - Natural bounce animation at zoom limits
- **Auto-Centering** - Image stays centered when smaller than the viewport
- **Device Rotation Support** - Maintains the visible center point when rotating the device
- **SwiftUI Native** - Drop-in SwiftUI component built on top of UIScrollView for optimal performance

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add ZoomableImageView to your project using Swift Package Manager:

1. In Xcode, go to **File > Add Package Dependencies...**
2. Enter the repository URL:
   ```
   https://github.com/diogomusou/ZoomableImageView.git
   ```
3. Select the version and click **Add Package**

Or add it directly to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/diogomusou/ZoomableImageView.git", from: "1.0.0")
]
```

## Usage

```swift
import SwiftUI
import ZoomableImageView

struct ContentView: View {
    var body: some View {
        ZoomableImageView(image: UIImage(named: "photo")!)
    }
}
```

### Custom Maximum Zoom Scale

```swift
ZoomableImageView(image: myImage, maximumZoomScale: 10)
```

The default maximum zoom scale is 5x.

## How It Works

ZoomableImageView wraps a `UIScrollView` with a `UIImageView` to leverage UIKit's battle-tested zoom and pan implementation. The component:

- Automatically calculates the minimum zoom scale to fit the image within the available space
- Centers the image when it's smaller than the scroll view bounds
- Preserves the visible center point during device rotation for a seamless experience
- Uses aspect-fit scaling to display the entire image without cropping

## License

MIT License. See [LICENSE](LICENSE) for details.
