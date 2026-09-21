import CoreGraphics

enum ScreenCoordinateSpace {
    /// Equivalent to the original screenshot-pixel → display-point → global AppKit mapping.
    static func globalPoint(imagePoint: CGPoint, imageSize: CGSize, displayFrame: CGRect) -> CGPoint? {
        guard imageSize.width > 0, imageSize.height > 0,
              imagePoint.x.isFinite, imagePoint.y.isFinite,
              imagePoint.x >= 0, imagePoint.x < imageSize.width,
              imagePoint.y >= 0, imagePoint.y < imageSize.height else { return nil }
        return CGPoint(x: displayFrame.minX + imagePoint.x * displayFrame.width / imageSize.width,
                       y: displayFrame.maxY - imagePoint.y * displayFrame.height / imageSize.height)
    }

    static func overlayPoint(globalPoint: CGPoint, displayFrame: CGRect) -> CGPoint {
        CGPoint(x: globalPoint.x - displayFrame.minX, y: displayFrame.maxY - globalPoint.y)
    }
}
