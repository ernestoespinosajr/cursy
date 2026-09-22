import AppKit
import SwiftUI
import Combine

private final class HomePanel: CursyEditingPanel {
    // HomePanelLayout already clamps each mode. AppKit's default visibleFrame
    // constraint would push an attached island back below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

private final class HomeHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

@MainActor
final class HomePanelController {
    private let companionManager: CompanionManager
    private let model = HomePresentationModel()
    private var panel: NSPanel?
    private var displayID: UInt32?
    private var screenObserver: NSObjectProtocol?
    private var moveObserver: NSObjectProtocol?
    private var escapeMonitor: Any?
    private var localEscapeMonitor: Any?
    private var transitionID = UUID()
    private var requestedPresentation: HomePresentation = .hidden
    private var globalPointerMonitor: Any?
    private var localPointerMonitor: Any?
    private var voiceSubscription: AnyCancellable?
    private var activationSubscription: AnyCancellable?
    private var activationFallback: DispatchWorkItem?
    private var hoverWork: DispatchWorkItem?
    private var hoverIntent: HomeHoverIntent = .none
    private var hoverDisplayID: UInt32?
    private var hoverRequest = UUID()
    private var suppressHoverUntilExit = false
    private var autoClosing = false
    private var previousVoiceState: CompanionVoiceState = .idle
    private var dismissedDuringTurn = false

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenConfigurationChanged() }
        }
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
        if let globalPointerMonitor { NSEvent.removeMonitor(globalPointerMonitor) }
        if let localPointerMonitor { NSEvent.removeMonitor(localPointerMonitor) }
        hoverWork?.cancel()
        activationFallback?.cancel()
    }

    /// Passive pointer events only: no screen capture, audio, focus or input injection.
    func startHoverMonitoring() {
        guard globalPointerMonitor == nil, localPointerMonitor == nil else { return }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                             .otherMouseDragged, .leftMouseUp, .rightMouseUp, .scrollWheel]
        globalPointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            self?.updateHoverIntent()
        }
        localPointerMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.updateHoverIntent()
            return event
        }
        voiceSubscription = companionManager.$voiceState.removeDuplicates()
            .receive(on: RunLoop.main).sink { [weak self] state in
                guard let self else { return }
                self.voiceActivityChanged(state)
                if self.autoClosing && self.companionManager.voiceState != .idle {
                    self.autoClosing = false
                    self.present(self.model.presentation)
                }
                self.updateHoverIntent()
            }
        activationSubscription = companionManager.$voiceNotchActivatedID
            .receive(on: RunLoop.main).sink { [weak self] id in
                guard let self, let id, id == self.companionManager.voiceNotchActivationID else { return }
                self.showAutomaticIslandIfReady()
            }
    }

    private func voiceActivityChanged(_ state: CompanionVoiceState) {
        let startsTurn = (previousVoiceState == .idle && state != .idle) ||
            ((state == .connecting || state == .listening) &&
             (previousVoiceState == .processing || previousVoiceState == .responding))
        previousVoiceState = state
        if state == .idle {
            dismissedDuringTurn = false
            companionManager.voiceNotchAnchor = nil
            companionManager.voiceNotchActivationID = nil
            companionManager.voiceNotchActivatedID = nil
            activationFallback?.cancel()
            // The common hover policy keeps the same idle grace, pointer and
            // VoiceOver protections for automatic and manually opened surfaces.
            return
        }
        if startsTurn {
            dismissedDuringTurn = false
            activationFallback?.cancel()
            companionManager.voiceNotchActivatedID = nil
            companionManager.voiceNotchActivationID = UUID()
            if requestedPresentation == .hidden {
                displayID = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }.map(Self.identifier)
            }
        }
        guard requestedPresentation != .detached, !dismissedDuringTurn,
              let screen = selectedScreen() else {
            companionManager.voiceNotchAnchor = nil
            return
        }
        let notch = HomePanelLayout.notch(screenFrame: screen.frame, safeTopInset: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea)
        companionManager.voiceNotchAnchor = notch.map { HomeNotchAnchor(displayFrame: screen.frame, cameraFrame: $0) }
        showAutomaticIslandIfReady()
        if startsTurn, notch != nil {
            // A missing/recreated overlay must not leave listening feedback absent forever.
            let id = companionManager.voiceNotchActivationID
            let fallback = DispatchWorkItem { [weak self] in
                guard let self, self.companionManager.voiceNotchActivationID == id,
                      self.companionManager.voiceState != .idle else { return }
                self.showAutomaticIslandIfReady(force: true)
            }
            activationFallback = fallback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: fallback)
        }
    }

    private func showAutomaticIslandIfReady(force: Bool = false) {
        let ready = HomeNotchInteraction.activationReady(request: companionManager.voiceNotchActivationID,
            completed: companionManager.voiceNotchActivatedID, hasCamera: companionManager.voiceNotchAnchor != nil,
            voiceState: companionManager.voiceState, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        guard ready || force else { return }
        if HomeNotchInteraction.shouldShowIsland(voiceState: companionManager.voiceState,
            presentation: requestedPresentation, dismissedDuringTurn: dismissedDuringTurn) {
            cancelHoverRequest()
            autoClosing = false
            present(.compact)
        }
    }

    private func pointerIntent() -> (HomeHoverIntent, UInt32?) {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) }
        let notch = screen.flatMap {
            HomePanelLayout.notch(screenFrame: $0.frame, safeTopInset: $0.safeAreaInsets.top,
                                  leftArea: $0.auxiliaryTopLeftArea, rightArea: $0.auxiliaryTopRightArea)
        }
        // A small strip below the physical camera makes its lower edge reachable.
        let inTrigger = notch.map {
            CGRect(x: $0.minX, y: $0.minY - 6, width: $0.width, height: $0.height + 6).contains(point)
        } ?? false
        let inPanel = panelContains(point)
        if let panel, requestedPresentation != .hidden {
            // Transparent shoulders must not swallow clicks intended for the menu bar.
            panel.ignoresMouseEvents = !inPanel
        }
        if !inTrigger && !inPanel { suppressHoverUntilExit = false }
        let intent = HomeHoverPolicy.intent(presentation: requestedPresentation,
            inTrigger: inTrigger, inPanel: inPanel, busy: companionManager.voiceState != .idle || companionManager.isGuideActive || panel?.isKeyWindow == true,
            dragging: NSEvent.pressedMouseButtons != 0, suppressed: suppressHoverUntilExit,
            voiceOver: NSWorkspace.shared.isVoiceOverEnabled, closing: autoClosing,
            setupRequired: !companionManager.allPermissionsGranted || !companionManager.hasCompletedOnboarding)
        return (intent, screen.map(Self.identifier))
    }

    private func panelContains(_ point: CGPoint) -> Bool {
        guard let panel, panel.isVisible, panel.frame.contains(point) else { return false }
        let localPoint = CGPoint(x: point.x - panel.frame.minX, y: panel.frame.maxY - point.y)
        let bounds = CGRect(origin: .zero, size: panel.frame.size)
        if model.notchWidth > 0 && model.presentation == .compact {
            return HomeIslandShape().path(in: bounds).contains(localPoint)
        }
        return HomeSurfaceShape(notchWidth: model.notchWidth, notchHeight: model.notchHeight)
            .path(in: bounds).contains(localPoint)
    }

    private func cancelHoverRequest() {
        hoverWork?.cancel()
        hoverWork = nil
        hoverIntent = .none
        hoverDisplayID = nil
        hoverRequest = UUID()
    }

    private func updateHoverIntent() {
        let (intent, screenID) = pointerIntent()
        guard intent != .none else { cancelHoverRequest(); return }
        if intent == .open && autoClosing {
            cancelHoverRequest()
            autoClosing = false
            present(model.presentation)
            return
        }
        // Motion inside the same region must not restart the dwell timer.
        guard intent != hoverIntent || screenID != hoverDisplayID else { return }
        cancelHoverRequest()
        hoverIntent = intent
        hoverDisplayID = screenID
        let request = hoverRequest
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.hoverRequest == request else { return }
            let current = self.pointerIntent()
            self.cancelHoverRequest()
            guard current.0 == intent, current.1 == screenID else { return }
            if intent == .open {
                self.autoClosing = false
                self.displayID = screenID
                self.present(.expanded)
            } else {
                self.autoClosing = true
                self.present(.hidden)
            }
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() +
            (intent == .open ? HomeHoverPolicy.openDelay : HomeHoverPolicy.hideDelay), execute: work)
    }

    private func handlePresentationRequest(_ presentation: HomePresentation) {
        cancelHoverRequest()
        autoClosing = false
        if presentation == .hidden {
            suppressHoverUntilExit = true
            dismissedDuringTurn = companionManager.voiceState != .idle
            companionManager.voiceNotchAnchor = nil
            activationFallback?.cancel()
        }
        if presentation == .detached { companionManager.voiceNotchAnchor = nil }
        present(presentation)
        if presentation != .hidden { voiceActivityChanged(companionManager.voiceState) }
        updateHoverIntent()
    }

    func toggle() {
        if HomePresentation.afterStatusItemClick(from: requestedPresentation) == .expanded {
            show()
        } else {
            hide()
        }
    }

    func hide() { handlePresentationRequest(.hidden) }

    func show() {
        cancelHoverRequest()
        suppressHoverUntilExit = false
        autoClosing = false
        dismissedDuringTurn = false
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main ?? NSScreen.screens.first
        displayID = screen.map(Self.identifier)
        present(.expanded)
        voiceActivityChanged(companionManager.voiceState)
        updateHoverIntent()
    }

    private func present(_ presentation: HomePresentation, animated: Bool = true, afterCollapse: Bool = false) {
        if presentation == .hidden, companionManager.walkthrough.isFollowing {
            companionManager.walkthrough.pause()
        }
        let wasVisible = panel?.isVisible == true
        let previous = model.presentation
        // Preserve the screen reached by dragging before changing presentation.
        if previous == .detached { _ = selectedScreen() }
        transitionID = UUID()
        let request = transitionID
        requestedPresentation = presentation
        if presentation == .hidden || presentation == .compact {
            (panel as? CursyEditingPanel)?.endEditing()
            companionManager.homeMicrophone.stop()
            companionManager.homeShortcutRecorder.stop()
        }
        let animation = Animation.timingCurve(0.23, 1, 0.32, 1,
            duration: HomeNotchInteraction.duration)
        if animated && wasVisible && previous != .hidden && presentation != .hidden &&
            previous != presentation && !afterCollapse {
            companionManager.homeSpatialHintAnchor = nil
            // Change layout behind the camera, never resize a visible text surface.
            withAnimation(animation) { model.reveal = 0 } completion: { [weak self] in
                guard let self, self.transitionID == request else { return }
                self.present(presentation, animated: animated, afterCollapse: true)
            }
            return
        }
        guard presentation != .hidden else {
            companionManager.homeSpatialHintAnchor = nil
            removeEscapeMonitors()
            panel?.ignoresMouseEvents = true
            withAnimation(animation) {
                model.reveal = 0
            } completion: { [weak self] in
                guard let self, self.transitionID == request else { return }
                self.panel?.orderOut(nil)
                self.model.presentation = .hidden
                self.autoClosing = false
            }
            return
        }
        model.presentation = presentation
        if panel == nil { createPanel() }
        guard let screen = selectedScreen(), let panel else { return }
        let notch = HomePanelLayout.notch(screenFrame: screen.frame,
            safeTopInset: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea)
        model.notchWidth = presentation == .detached ? 0 : notch?.width ?? 0
        model.notchHeight = presentation == .detached ? 0 : notch?.height ?? 0
        panel.level = model.notchWidth > 0 ? .statusBar : .floating
        panel.isMovableByWindowBackground = presentation == .detached
        panel.ignoresMouseEvents = false
        let frame = HomePanelLayout.frame(presentation: presentation, screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame, safeTopInset: screen.safeAreaInsets.top, notch: notch)
        // Resizing a real panel avoids a screen-sized invisible hit-test surface.
        // Resize once, then reveal a mask. AppKit frame animation would stretch
        // the text and briefly misalign the physical camera reserved area.
        if !wasVisible || previous != presentation { model.reveal = 0 }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        updateSpatialHintAnchor()
        installEscapeMonitors()
        // Give the newly ordered hosting view its initial (closed) geometry.
        // A newer close/open invalidates this completion; no delayed hide may win.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.transitionID == request else { return }
            withAnimation(animated ? animation : nil) { self.model.reveal = 1 }
        }
    }

    private func createPanel() {
        let homePanel = HomePanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        homePanel.title = "Cursy"
        homePanel.isReleasedWhenClosed = false
        homePanel.isFloatingPanel = true
        homePanel.hidesOnDeactivate = false
        homePanel.acceptsMouseMovedEvents = true
        homePanel.level = .floating
        homePanel.isOpaque = false
        homePanel.backgroundColor = .clear
        // Native window shadows would outline the transparent skirt/camera join.
        homePanel.hasShadow = false
        homePanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        homePanel.isExcludedFromWindowsMenu = true
        let hostingView = HomeHostingView(rootView: HomeView(companionManager: companionManager,
            model: model, onPresent: { [weak self] in self?.handlePresentationRequest($0) }))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        homePanel.contentView = hostingView
        panel = homePanel
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: homePanel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateSpatialHintAnchor() }
        }
    }

    private func updateSpatialHintAnchor() {
        guard requestedPresentation != .hidden, let panel, panel.isVisible,
              let screen = selectedScreen() else {
            companionManager.homeSpatialHintAnchor = nil
            return
        }
        let camera = HomePanelLayout.notch(screenFrame: screen.frame, safeTopInset: screen.safeAreaInsets.top,
            leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea)
        companionManager.homeSpatialHintAnchor = HomeSpatialHintAnchor.make(
            presentation: model.presentation, panelFrame: panel.frame,
            displayFrame: screen.frame, cameraFrame: camera)
    }

    private func selectedScreen() -> NSScreen? {
        if model.presentation == .detached, let windowScreen = panel?.screen,
           NSScreen.screens.contains(where: { Self.identifier($0) == Self.identifier(windowScreen) }) {
            displayID = Self.identifier(windowScreen)
            return windowScreen
        }
        let screen = NSScreen.screens.first { Self.identifier($0) == displayID }
            ?? NSScreen.main ?? NSScreen.screens.first
        displayID = screen.map(Self.identifier)
        return screen
    }

    private func screenConfigurationChanged() {
        cancelHoverRequest()
        activationFallback?.cancel()
        companionManager.voiceNotchActivatedID = nil
        companionManager.voiceNotchActivationID = companionManager.voiceState == .idle ? nil : UUID()
        companionManager.voiceNotchAnchor = nil
        voiceActivityChanged(companionManager.voiceState)
        guard requestedPresentation != .hidden, let panel, let screen = selectedScreen() else { return }
        if model.presentation == .detached {
            panel.setFrame(HomePanelLayout.clamped(panel.frame, to: screen.visibleFrame), display: true)
        } else {
            present(model.presentation, animated: false)
        }
        updateHoverIntent()
    }

    private func installEscapeMonitors() {
        guard escapeMonitor == nil, localEscapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.handlePresentationRequest(.hidden) }
        }
        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.handlePresentationRequest(.hidden) }
            return event
        }
    }

    private func removeEscapeMonitors() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor) }
        escapeMonitor = nil
        localEscapeMonitor = nil
    }

    private static func identifier(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
