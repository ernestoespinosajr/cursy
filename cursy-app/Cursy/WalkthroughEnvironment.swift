import AppKit
import Carbon

/// Content-free lifecycle signals. Secure input suppresses capture, never attempts bypass.
@MainActor
final class WalkthroughEnvironment {
    private var eventMonitor: Any?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lockObserver: NSObjectProtocol?

    static var canObserve: Bool {
        guard !IsSecureEventInputEnabled(), CGPreflightScreenCaptureAccess(), AXIsProcessTrusted() else { return false }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
           let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
            let focused = value as! AXUIElement
            AXUIElementSetMessagingTimeout(focused, 0.05)
            var subrole: CFTypeRef?
            AXUIElementCopyAttributeValue(focused, kAXSubroleAttribute as CFString, &subrole)
            if subrole as? String == "AXSecureTextField" { return false }
        }
        return true
    }

    func start(changed: @escaping () -> Void, unavailable: @escaping () -> Void) {
        guard workspaceObservers.isEmpty else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel, .leftMouseUp, .keyUp]) { _ in
            Task { @MainActor in changed() }
        }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { _ in Task { @MainActor in changed() } })
        for notification in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                             NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: notification, object: nil, queue: .main) { _ in
                Task { @MainActor in unavailable() }
            })
        }
        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
                Task { @MainActor in unavailable() }
            }
    }

    func stop() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        if let lockObserver { DistributedNotificationCenter.default().removeObserver(lockObserver) }
        lockObserver = nil
    }
}
