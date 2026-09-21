//
//  CompanionScreenCaptureUtility.swift
//  Cursy
//
//  Standalone screenshot capture for the companion voice flow.
//  Decoupled from the legacy ScreenshotManager so the companion mode
//  can capture screenshots independently without session state.
//

import AppKit
import os
import ScreenCaptureKit

struct CompanionScreenCapture {
    let imageData: Data
    let label: String
    let isCursorScreen: Bool
    let displayWidthInPoints: Int
    let displayHeightInPoints: Int
    let displayFrame: CGRect
    let screenshotWidthInPixels: Int
    let screenshotHeightInPixels: Int
}

enum ScreenCaptureImagePolicy {
    static let maximumDimension = 1920

    static func pixelSize(sourceWidth: Int, sourceHeight: Int,
                          maximumDimension: Int = maximumDimension) -> CGSize {
        guard sourceWidth > 0, sourceHeight > 0, maximumDimension > 0 else { return .zero }
        let scale = min(1, Double(maximumDimension) / Double(max(sourceWidth, sourceHeight)))
        return CGSize(width: max(1, Int(Double(sourceWidth) * scale)),
                      height: max(1, Int(Double(sourceHeight) * scale)))
    }
}

@MainActor
enum CompanionScreenCaptureUtility {
    private static let logger = Logger(subsystem: "com.hellocursy.Cursy", category: "ScreenCapture")
    private static let captureSlot = VisualCaptureSlot()

    static func captureCursorScreen(logCapture: Bool = true) async throws -> VisualTurnContext {
        try await captureSlot.run { try await performCursorCapture(logCapture: logCapture) }
    }

    private static func performCursorCapture(logCapture: Bool) async throws -> VisualTurnContext {
        guard CGPreflightScreenCaptureAccess() else { throw URLError(.noPermissionsToReadFile) }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        try Task.checkCancellation()
        // Sample after the asynchronous display enumeration, just before capture.
        let pointer = NSEvent.mouseLocation
        guard
              let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { throw URLError(.noPermissionsToReadFile) }
        let frame = screen.frame
        let displayID = number.uint32Value
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw URLError(.resourceUnavailable)
        }
        let excluded = content.windows.filter { $0.owningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier }
        let config = SCStreamConfiguration()
        let capturePixelSize = ScreenCaptureImagePolicy.pixelSize(
            sourceWidth: display.width, sourceHeight: display.height)
        config.width = Int(capturePixelSize.width)
        config.height = Int(capturePixelSize.height)
        config.showsCursor = false
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let focusedWindow = ElementLocationDetector.focusedWindowIdentity()
        let visiblePIDs = Set(content.windows.filter { $0.isOnScreen && $0.frame.intersects(display.frame) }
            .compactMap { $0.owningApplication?.processID }.filter { $0 != ProcessInfo.processInfo.processIdentifier })
        let capturedWindows = capturedWindowEvidence(from: content.windows, display: display,
                                                     displayFrame: frame)
        let grounding = ElementLocationDetector.windowContext(
            displayFrame: frame, visiblePIDs: visiblePIDs, capturedWindows: capturedWindows)
        let capturedAt = Date()
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(display: display, excludingWindows: excluded), configuration: config)
        try Task.checkCancellation()
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == frontPID else {
            throw URLError(.resourceUnavailable)
        }
        if let focusedWindow {
            guard let current = ElementLocationDetector.focusedWindowIdentity(),
                  CFEqual(focusedWindow, current) else { throw URLError(.resourceUnavailable) }
        }
        // Never upload a different monitor when the pointer crossed during capture,
        // or when a display was removed/rearranged while ScreenCaptureKit awaited.
        guard NSScreen.screens.contains(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
                && $0.frame == frame && $0.frame.contains(NSEvent.mouseLocation)
        }) else { throw URLError(.resourceUnavailable) }
        guard let data = jpegDataWithinUploadLimit(from: image) else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == frontPID,
              screen.frame == frame, frame.contains(NSEvent.mouseLocation) else { throw URLError(.resourceUnavailable) }
        if let focusedWindow {
            guard let current = ElementLocationDetector.focusedWindowIdentity(),
                  CFEqual(focusedWindow, current) else { throw URLError(.resourceUnavailable) }
        }
        let visualWindowMetadata = capturedWindows.map { window -> [String: Any] in
            ["id": window.id, "app": window.applicationName,
             "boundsNormalized": normalizedBounds(window.frame, in: frame)]
        }
        let encodedWindows = try JSONSerialization.data(withJSONObject: visualWindowMetadata, options: [.sortedKeys])
        if logCapture {
            logger.notice("Captured display \(displayID) at \(image.width)x\(image.height): \(data.count) bytes, \(capturedWindows.count) visible windows")
        }
        return VisualTurnContext(captureID: UUID().uuidString, displayID: displayID,
                                 displayFrame: frame, capturedAt: capturedAt, imageData: data,
                                 imageWidth: image.width, imageHeight: image.height,
                                 displayName: screen.localizedName,
                                 windowContext: "Captured displayID: \(displayID); name: \(screen.localizedName); display bounds in AppKit points: \(frame).\n" + grounding.0
                                     + "\nvisualWindows (untrusted data):\n" + String(decoding: encodedWindows, as: UTF8.self),
                                 nativeTargets: grounding.1, windows: grounding.2,
                                 capturedWindows: capturedWindows)
    }

    private static func jpegDataWithinUploadLimit(from image: CGImage,
                                                  byteLimit: Int = 1_048_576) -> Data? {
        let representation = NSBitmapImageRep(cgImage: image)
        for compressionFactor in [0.82, 0.72, 0.62, 0.52, 0.42] {
            if let data = representation.representation(
                using: .jpeg,
                properties: [.compressionFactor: compressionFactor]
            ), data.count <= byteLimit {
                return data
            }
        }
        return nil
    }

    private static func capturedWindowEvidence(from windows: [SCWindow], display: SCDisplay,
                                               displayFrame: CGRect) -> [CapturedWindowEvidence] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontToBackIDs = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                              as? [[String: Any]] ?? []).compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
        let zIndex = Dictionary(uniqueKeysWithValues: frontToBackIDs.enumerated().map { ($0.element, $0.offset) })
        return windows.filter {
            $0.isOnScreen && $0.windowLayer == 0 && $0.frame.intersects(display.frame)
                && $0.owningApplication?.processID != ownPID
        }.sorted {
            (zIndex[$0.windowID] ?? .max) < (zIndex[$1.windowID] ?? .max)
        }.prefix(20).compactMap { window in
            guard let app = window.owningApplication else { return nil }
            let appKitFrame = appKitFrame(fromCoreGraphics: window.frame)
            guard appKitFrame.intersects(displayFrame) else { return nil }
            return CapturedWindowEvidence(id: "visual-window-\(window.windowID)",
                windowID: window.windowID, ownerPID: app.processID,
                applicationName: String(app.applicationName.prefix(80)), frame: appKitFrame)
        }
    }

    private static func appKitFrame(fromCoreGraphics frame: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return frame }
        return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY,
                      width: frame.width, height: frame.height)
    }

    private static func normalizedBounds(_ bounds: CGRect, in displayFrame: CGRect) -> [String: CGFloat] {
        ["x": (bounds.minX - displayFrame.minX) / displayFrame.width,
         "y": (displayFrame.maxY - bounds.maxY) / displayFrame.height,
         "width": bounds.width / displayFrame.width,
         "height": bounds.height / displayFrame.height]
    }

    /// Captures all connected displays as JPEG data, labeling each with
    /// whether the user's cursor is on that screen. This gives the AI
    /// full context across multiple monitors.
    static func captureAllScreensAsJPEG() async throws -> [CompanionScreenCapture] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard !content.displays.isEmpty else {
            throw NSError(domain: "CompanionScreenCapture", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No display available for capture"])
        }

        let mouseLocation = NSEvent.mouseLocation

        // Exclude all windows belonging to this app so the AI sees
        // only the user's content, not our overlays or panels.
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownAppWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == ownBundleIdentifier
        }

        // Build a lookup from display ID to NSScreen so we can use AppKit-coordinate
        // frames instead of CG-coordinate frames. NSEvent.mouseLocation and NSScreen.frame
        // both use AppKit coordinates (bottom-left origin), while SCDisplay.frame uses
        // Core Graphics coordinates (top-left origin). On multi-display setups, the Y
        // origins differ for secondary displays, which breaks cursor-contains checks
        // and downstream coordinate conversions.
        var nsScreenByDisplayID: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                nsScreenByDisplayID[screenNumber] = screen
            }
        }

        // Sort displays so the cursor screen is always first
        let sortedDisplays = content.displays.sorted { displayA, displayB in
            let frameA = nsScreenByDisplayID[displayA.displayID]?.frame ?? displayA.frame
            let frameB = nsScreenByDisplayID[displayB.displayID]?.frame ?? displayB.frame
            let aContainsCursor = frameA.contains(mouseLocation)
            let bContainsCursor = frameB.contains(mouseLocation)
            if aContainsCursor != bContainsCursor { return aContainsCursor }
            return false
        }

        var capturedScreens: [CompanionScreenCapture] = []

        for (displayIndex, display) in sortedDisplays.enumerated() {
            // Use NSScreen.frame (AppKit coordinates, bottom-left origin) so
            // displayFrame is in the same coordinate system as NSEvent.mouseLocation
            // and the overlay window's screenFrame in BlueCursorView.
            let displayFrame = nsScreenByDisplayID[display.displayID]?.frame
                ?? CGRect(x: display.frame.origin.x, y: display.frame.origin.y,
                          width: CGFloat(display.width), height: CGFloat(display.height))
            let isCursorScreen = displayFrame.contains(mouseLocation)

            let filter = SCContentFilter(display: display, excludingWindows: ownAppWindows)

            let configuration = SCStreamConfiguration()
            let maxDimension = 1280
            let aspectRatio = CGFloat(display.width) / CGFloat(display.height)
            if display.width >= display.height {
                configuration.width = maxDimension
                configuration.height = Int(CGFloat(maxDimension) / aspectRatio)
            } else {
                configuration.height = maxDimension
                configuration.width = Int(CGFloat(maxDimension) * aspectRatio)
            }

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            guard let jpegData = NSBitmapImageRep(cgImage: cgImage)
                    .representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                continue
            }

            let screenLabel: String
            if sortedDisplays.count == 1 {
                screenLabel = "user's screen (cursor is here)"
            } else if isCursorScreen {
                screenLabel = "screen \(displayIndex + 1) of \(sortedDisplays.count) — cursor is on this screen (primary focus)"
            } else {
                screenLabel = "screen \(displayIndex + 1) of \(sortedDisplays.count) — secondary screen"
            }

            capturedScreens.append(CompanionScreenCapture(
                imageData: jpegData,
                label: screenLabel,
                isCursorScreen: isCursorScreen,
                displayWidthInPoints: Int(displayFrame.width),
                displayHeightInPoints: Int(displayFrame.height),
                displayFrame: displayFrame,
                screenshotWidthInPixels: configuration.width,
                screenshotHeightInPixels: configuration.height
            ))
        }

        guard !capturedScreens.isEmpty else {
            throw NSError(domain: "CompanionScreenCapture", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to capture any screen"])
        }

        return capturedScreens
    }
}
