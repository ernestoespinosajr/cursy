import AppKit
import Testing
@testable import Cursy

struct ScreenCoordinateSpaceTests {
    @Test func localizationRasterMatchesDeclaredSizeAndKeepsBottomRowPosition() throws {
        let sourceSize = CGSize(width: 1920, height: 1401)
        let drawing = try #require(CGContext(data: nil, width: Int(sourceSize.width),
            height: Int(sourceSize.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let source = try #require(drawing.makeImage())
        let png = try #require(NSBitmapImageRep(cgImage: source).representation(using: .png, properties: [:]))
        let prepared = try VisionLocalizationImage.prepare(png)
        let decoded = try #require(NSBitmapImageRep(data: prepared.data))
        #expect(prepared.width == 1052)
        #expect(prepared.height == 768)
        #expect(decoded.pixelsWide == prepared.width && decoded.pixelsHigh == prepared.height)
        let frame = CGRect(x: -1728, y: 200, width: 1728, height: 1117)
        let point = try #require(ScreenCoordinateSpace.globalPoint(
            imagePoint: CGPoint(x: 0.27 * Double(prepared.width), y: 0.94 * Double(prepared.height)),
            imageSize: CGSize(width: prepared.width, height: prepared.height), displayFrame: frame))
        #expect(abs(point.y - (frame.maxY - frame.height * 0.94)) < 0.00001)
        #expect(VisionLocalizationImage.pixelSize(width: 1440, height: 2560) == CGSize(width: 768, height: 1365))
        #expect(VisionLocalizationImage.pixelSize(width: 512, height: 512) == CGSize(width: 512, height: 512))
        #expect(VisionLocalizationImage.pixelSize(width: 6000, height: 1000) == CGSize(width: 2048, height: 341))
    }

    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 1728, height: 1117),
        CGRect(x: 1728, y: -200, width: 2560, height: 1440),
        CGRect(x: -2560, y: 400, width: 2560, height: 1440),
        CGRect(x: 0, y: 1117, width: 1440, height: 2560)
    ])
    func bottomRowReachesSamePositionAcrossImageScalesAndMonitors(frame: CGRect) throws {
        for imageSize in [CGSize(width: 1280, height: 720), CGSize(width: 1920, height: 1080)] {
            let imagePoint = CGPoint(x: imageSize.width * 0.27, y: imageSize.height * 0.94)
            let global = try #require(ScreenCoordinateSpace.globalPoint(
                imagePoint: imagePoint, imageSize: imageSize, displayFrame: frame))
            let overlay = ScreenCoordinateSpace.overlayPoint(globalPoint: global, displayFrame: frame)
            #expect(abs(overlay.x - frame.width * 0.27) < 0.00001)
            #expect(abs(overlay.y - frame.height * 0.94) < 0.00001)
        }
    }

    @Test func providerCannotMixImageDimensionsOrReturnOutsidePixels() throws {
        let context = VisualTurnContext(captureID: "qa", displayID: 2,
            displayFrame: CGRect(x: 1728, y: 0, width: 2560, height: 1440),
            capturedAt: .now, imageData: Data(), imageWidth: 1920, imageHeight: 1080,
            capturedWindows: [CapturedWindowEvidence(id: "window", windowID: 1, ownerPID: 1,
                applicationName: "Fixture", frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440))])
        func target(width: Int, x: Double) -> ImagePointingTarget {
            ImagePointingTarget(captureID: "qa", imageWidth: width, imageHeight: 1080,
                x: x, y: 1015.2, label: "Element", nativeControlID: "", intent: "other", windowID: "window")
        }
        #expect(target(width: 1280, x: 518.4).normalized(for: context) == nil)
        #expect(target(width: 1920, x: 1920).normalized(for: context) == nil)
        #expect(target(width: 1920, x: .nan).normalized(for: context) == nil)
        let normalized = try #require(target(width: 1920, x: 518.4).normalized(for: context))
        let global = try #require(context.location(for: normalized, currentFrame: context.displayFrame))
        #expect(abs(global.x - 2419.2) < 0.00001)
        #expect(abs(global.y - 86.4) < 0.00001)
    }
}
