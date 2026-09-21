import AppKit
import ApplicationServices
import os

nonisolated struct AccessibleSelection: Sendable {
    let context: SelectedTextContext
    let frame: CGRect
    let processID: pid_t
    let obstacles: [CGRect]
}

/// AX calls are synchronous IPC. Keep their bounded search off the UI thread.
actor SelectedTextReader {
    private let logger = Logger(subsystem: "Cursy", category: "SelectedText")
    private var warmup = SelectionAccessibilityWarmup()

    func prepare(processID: pid_t) async -> TimeInterval {
        let now = ProcessInfo.processInfo.systemUptime
        guard !Task.isCancelled, AXIsProcessTrusted() else { return now }
        let foreground = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
        guard !Task.isCancelled, foreground == processID else { return now }
        let application = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(application, 0.035)
        // Chromium starts its basic assistive interface on AXRole access. This
        // also works without the Electron-specific manual activation attribute.
        var role: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(application, kAXRoleAttribute as CFString, &role)
        let name = "AXManualAccessibility" as CFString
        return warmup.prepare(processID: processID, now: now, isEnabled: {
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(application, name, &value) == .success && (value as? Bool) == true
        }, isSettable: {
            var settable = DarwinBoolean(false)
            return AXUIElementIsAttributeSettable(application, name, &settable) == .success && settable.boolValue
        }, enable: {
            !Task.isCancelled && AXUIElementSetAttributeValue(application, name, kCFBooleanTrue) == .success
        })
    }

    func read(processID: pid_t, pointer: CGPoint?, desktopTop: CGFloat, requestID: UUID, gestureStart: CGPoint? = nil) async -> AccessibleSelection? {
        guard !Task.isCancelled, AXIsProcessTrusted() else { return nil }
        let readyAfter = await prepare(processID: processID)
        let initial = SelectionAXQuery(processID: processID, pointer: pointer, desktopTop: desktopTop)
        guard let window = initial.sourceWindow() else {
            logger.info("Selection request=\(requestID, privacy: .public) pid=\(processID) reason=no-window")
            return nil
        }
        let originalHit = pointer.flatMap { initial.hit($0) }
        // Let the selection range and its own action menu settle before placing
        // our panel. This is cancellable; no provisional panel covers the text.
        do { try await Task.sleep(for: .milliseconds(140)) } catch { return nil }
        for attempt in 0..<3 {
            if attempt > 0 {
                let delay = attempt == 1 ? 0.18 : max(0.3, readyAfter - ProcessInfo.processInfo.systemUptime)
                do { try await Task.sleep(for: .seconds(delay)) } catch { return nil }
            }
            let foreground = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
            guard !Task.isCancelled, foreground == processID else { return nil }
            let query = SelectionAXQuery(processID: processID, pointer: pointer, desktopTop: desktopTop, gestureStart: gestureStart)
            guard let currentWindow = query.sourceWindow(), CFEqual(currentWindow, window) else {
                logger.info("Selection request=\(requestID, privacy: .public) pid=\(processID) reason=window-changed")
                return nil
            }
            let result = query.read(window: window, originalHit: originalHit)
            logger.info("Selection request=\(requestID, privacy: .public) pid=\(processID) attempt=\(attempt) found=\(result != nil) candidates=\(query.visitedCount) selectedCandidates=\(query.selectedCandidates) limit=\(query.reachedLimit) timeout=\(!query.hasTime)")
            if let result {
                query.deadline = ProcessInfo.processInfo.systemUptime + 0.08
                if let currentWindow = query.sourceWindow(), CFEqual(currentWindow, window) { return result }
            }
        }
        return nil
    }
}

nonisolated private struct SelectionAXNode: Equatable {
    let element: AXUIElement
    static func == (lhs: Self, rhs: Self) -> Bool { CFEqual(lhs.element, rhs.element) }
}

/// Reads only selection attributes and structural/geometry attributes; never AXValue
/// (whole documents), clipboard, screenshots, application names or synthetic copy.
nonisolated private final class SelectionAXQuery: SelectionSearchBackend, SelectionMenuBackend {
    let processID: pid_t
    let pointer: CGPoint?
    let desktopTop: CGFloat
    let gestureStart: CGPoint?
    let application: AXUIElement
    var deadline = ProcessInfo.processInfo.systemUptime + 0.8
    private(set) var visitedCount = 0
    private(set) var selectedCandidates = 0
    private(set) var reachedLimit = false
    private var visited: [AXUIElement] = []
    var hasTime: Bool { !Task.isCancelled && ProcessInfo.processInfo.systemUptime < deadline }

    init(processID: pid_t, pointer: CGPoint?, desktopTop: CGFloat, gestureStart: CGPoint? = nil) {
        self.processID = processID
        self.pointer = pointer
        self.desktopTop = desktopTop
        self.gestureStart = gestureStart
        application = AXUIElementCreateApplication(processID)
    }
    func attribute(_ element: AXUIElement, _ name: CFString) -> CFTypeRef? {
        guard hasTime else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.035)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value
    }
    func parameter(_ element: AXUIElement, _ name: CFString, _ value: CFTypeRef) -> CFTypeRef? {
        guard hasTime else { return nil }
        AXUIElementSetMessagingTimeout(element, 0.035)
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, name, value, &result) == .success else { return nil }
        return result
    }
    func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    func appKit(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: desktopTop - rect.maxY, width: rect.width, height: rect.height)
    }
    func bounds(_ value: CFTypeRef?) -> CGRect? {
        guard let value else { return nil }
        var rect = CGRect.zero
        if CFGetTypeID(value) == AXValueGetTypeID() {
            guard AXValueGetValue(value as! AXValue, .cgRect, &rect) else { return nil }
        } else if let wrapped = value as? NSValue,
                  String(cString: wrapped.objCType) == String(cString: NSValue(rect: .zero).objCType) {
            rect = wrapped.rectValue
        } else { return nil }
        guard SelectionEvidence.validBounds(rect) else { return nil }
        return appKit(rect)
    }
    func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute as CFString),
              let size = attribute(element, kAXSizeAttribute as CFString),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        let rect = CGRect(origin: origin, size: dimensions)
        return SelectionEvidence.validBounds(rect) ? appKit(rect) : nil
    }
    func isSecure(_ element: AXUIElement) -> Bool {
        (attribute(element, kAXSubroleAttribute as CFString) as? String) == (kAXSecureTextFieldSubrole as String)
    }
    func selection(_ element: AXUIElement, pointerAnchor: CGPoint?) -> (SelectedTextContext, CGRect)? {
        guard hasTime, !visited.contains(where: { CFEqual($0, element) }), !isSecure(element) else { return nil }
        visited.append(element)
        visitedCount += 1
        var nativeText = attribute(element, kAXSelectedTextAttribute as CFString) as? String
        var nativeBounds: CGRect?
        if let range = attribute(element, kAXSelectedTextRangeAttribute as CFString), CFGetTypeID(range) == AXValueGetTypeID() {
            var selectedRange = CFRange()
            if AXValueGetValue(range as! AXValue, .cfRange, &selectedRange), selectedRange.length > 0,
               selectedRange.length <= SelectedTextContext.limit, selectedRange.location >= 0 {
                if nativeText?.isEmpty != false {
                    nativeText = parameter(element, kAXStringForRangeParameterizedAttribute as CFString, range) as? String
                }
                nativeBounds = bounds(parameter(element, kAXBoundsForRangeParameterizedAttribute as CFString, range))
            } else { nativeText = nil }
        }
        if nativeText?.isEmpty == false { selectedCandidates += 1 }
        if let result = SelectionEvidence.resolve(text: nativeText, bounds: nativeBounds, pointerAnchor: nil) { return result }

        // Web/Electron documents often expose an opaque marker range on their
        // web area, not a CFRange on the focused input or the hit text node.
        if let range = attribute(element, kAXSelectedTextMarkerRangeAttribute as CFString) {
            let length = parameter(element, kAXLengthForTextMarkerRangeParameterizedAttribute as CFString, range) as? NSNumber
            if length.map({ $0.intValue > 0 && $0.intValue <= SelectedTextContext.limit }) ?? true {
                let text = parameter(element, kAXStringForTextMarkerRangeParameterizedAttribute as CFString, range) as? String
                if text?.isEmpty == false { selectedCandidates += 1 }
                let rect = bounds(parameter(element, kAXBoundsForTextMarkerRangeParameterizedAttribute as CFString, range))
                if let result = SelectionEvidence.resolve(text: text, bounds: rect, pointerAnchor: pointerAnchor) { return result }
            }
        }
        return SelectionEvidence.resolve(text: nativeText, bounds: nativeBounds, pointerAnchor: pointerAnchor)
    }
    func hit(_ point: CGPoint) -> AXUIElement? {
        guard hasTime else { return nil }
        AXUIElementSetMessagingTimeout(application, 0.035)
        var value: AXUIElement?
        guard AXUIElementCopyElementAtPosition(application, Float(point.x), Float(desktopTop - point.y), &value) == .success else { return nil }
        return value
    }
    func sourceWindow() -> AXUIElement? {
        // A transient menu may own focus; the main document window still owns
        // the gesture. Window changes revoke all retries and pointer fallbacks.
        element(attribute(application, kAXMainWindowAttribute as CFString)) ??
        element(attribute(application, kAXFocusedWindowAttribute as CFString))
    }
    func read(window: AXUIElement, originalHit: AXUIElement?) -> AccessibleSelection? {
        let focused = element(attribute(application, kAXFocusedUIElementAttribute as CFString))
        if let focused, isSecure(focused) { return nil }
        let windowFrame = frame(window)
        let anchor = pointer.flatMap { point in windowFrame?.contains(point) == true ? point : nil }
        var search = SelectionTreeSearch(backend: self)
        let result = search.read(window: SelectionAXNode(element: window),
            hit: (originalHit ?? pointer.flatMap { hit($0) }).map { SelectionAXNode(element: $0) },
            focused: focused.map { SelectionAXNode(element: $0) }, anchor: anchor)
        reachedLimit = search.reachedLimit
        guard let result, let windowFrame else { return nil }
        let placement = SelectionPlacementEvidence.frame(reported: result.1, start: gestureStart, end: anchor, window: windowFrame)
        guard windowFrame.intersects(placement) else { return nil }
        // Menu placement gets its own small budget, even after a deep search.
        deadline = ProcessInfo.processInfo.systemUptime + 0.3
        return finish((result.0, placement), window: windowFrame)
    }

    var canContinue: Bool { hasTime }
    func parent(of node: SelectionAXNode) -> SelectionAXNode? {
        element(attribute(node.element, kAXParentAttribute as CFString)).map { SelectionAXNode(element: $0) }
    }
    func role(of node: SelectionAXNode) -> String? { attribute(node.element, kAXRoleAttribute as CFString) as? String }
    func isSecure(_ node: SelectionAXNode) -> Bool { isSecure(node.element) }
    func selectedText(in node: SelectionAXNode, anchor: CGPoint?) -> (SelectedTextContext, CGRect)? {
        selection(node.element, pointerAnchor: anchor)
    }
    func children(of node: SelectionAXNode, offset: Int, limit: Int) -> [SelectionAXNode] {
        guard hasTime else { return [] }
        var values: CFArray?
        AXUIElementSetMessagingTimeout(node.element, 0.035)
        guard AXUIElementCopyAttributeValues(node.element, kAXChildrenAttribute as CFString, offset, limit, &values) == .success,
              let children = values as? [AXUIElement] else { return [] }
        return children.map { SelectionAXNode(element: $0) }
    }
    func hit(at point: CGPoint) -> SelectionAXNode? {
        hit(point).map { SelectionAXNode(element: $0) }
    }
    func bounds(of node: SelectionAXNode) -> CGRect? { frame(node.element) }
    func finish(_ result: (SelectedTextContext, CGRect), window: CGRect) -> AccessibleSelection {
        let (context, selection) = result
        var search = SelectionMenuSearch(backend: self)
        let obstacles = search.read(selection: selection, window: window)
        return AccessibleSelection(context: context, frame: selection, processID: processID, obstacles: obstacles)
    }
}
