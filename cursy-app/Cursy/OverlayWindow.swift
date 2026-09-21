//
//  OverlayWindow.swift
//  Cursy
//
//  System-wide transparent overlay window for glass cursor.
//  One OverlayWindow is created per screen so the cursor buddy
//  seamlessly follows the cursor across multiple monitors.
//

import AppKit
import AVFoundation
import SwiftUI
import Combine

class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        // Create window covering entire screen
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Make window transparent and non-interactive
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver  // Always on top, above submenus and popups
        self.ignoresMouseEvents = true  // Click-through
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        self.hasShadow = false

        // Important: Allow the window to appear even when app is not active
        self.hidesOnDeactivate = false

        // Cover the entire screen
        self.setFrame(screen.frame, display: true)

        // Make sure it's on the right screen
        if let screenForWindow = NSScreen.screens.first(where: { $0.frame == screen.frame }) {
            self.setFrameOrigin(screenForWindow.frame.origin)
        }
    }

    // Prevent window from becoming key (no focus stealing)
    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}

// Cursor-like triangle shape (equilateral)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let height = size * sqrt(3.0) / 2.0

        // Top vertex
        path.move(to: CGPoint(x: rect.midX, y: rect.midY - height / 1.5))
        // Bottom left vertex
        path.addLine(to: CGPoint(x: rect.midX - size / 2, y: rect.midY + height / 3))
        // Bottom right vertex
        path.addLine(to: CGPoint(x: rect.midX + size / 2, y: rect.midY + height / 3))
        path.closeSubpath()
        return path
    }
}

// PreferenceKey for tracking bubble size
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct NavigationBubbleSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// The buddy's behavioral mode. Controls whether it follows the cursor,
/// is flying toward a detected UI element, or is pointing at an element.
enum BuddyNavigationMode {
    /// Default — buddy follows the mouse cursor with spring animation
    case followingCursor
    /// Buddy is animating toward a detected UI element location
    case navigatingToTarget
    /// Buddy has arrived at the target and is pointing at it with a speech bubble
    case pointingAtTarget
}

// SwiftUI view for the glass cursor pointer.
// Each screen gets its own BlueCursorView. The view checks whether
// the cursor is currently on THIS screen and only shows the buddy
// triangle when it is. During voice interaction, the triangle is
// replaced by a waveform (listening), spinner (processing), or
// streaming text bubble (responding).
struct BlueCursorView: View {
    let screenFrame: CGRect
    let isFirstAppearance: Bool
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum NotchFlightPhase { case following, entering, clicking, docked, leaving }
    @State private var notchFlightPhase: NotchFlightPhase = .following
    @State private var navigationRevision = UUID()
    @State private var notchActivationID: UUID?
    @State private var notchClickTask: Task<Void, Never>?
    @State private var notchClickScale: CGFloat = 1
    @State private var annotationElapsed: Double = 0
    @State private var annotationOpacity: Double = 1
    @State private var playingAnnotationID: UUID?
    @State private var annotationPlaybackRevision = UUID()
    @State private var annotationPointer: CGPoint = .zero

    @State private var cursorPosition: CGPoint
    @State private var isCursorOnThisScreen: Bool

    init(screenFrame: CGRect, isFirstAppearance: Bool, companionManager: CompanionManager) {
        self.screenFrame = screenFrame
        self.isFirstAppearance = isFirstAppearance
        self.companionManager = companionManager

        // Seed the cursor position from the current mouse location so the
        // buddy doesn't flash at (0,0) before onAppear fires.
        let mouseLocation = NSEvent.mouseLocation
        let localX = mouseLocation.x - screenFrame.origin.x
        let localY = screenFrame.height - (mouseLocation.y - screenFrame.origin.y)
        _cursorPosition = State(initialValue: CGPoint(x: localX + 35, y: localY + 25))
        _isCursorOnThisScreen = State(initialValue: screenFrame.contains(mouseLocation))
    }
    @State private var timer: Timer?
    @State private var welcomeText: String = ""
    @State private var showWelcome: Bool = true
    @State private var bubbleSize: CGSize = .zero
    @State private var bubbleOpacity: Double = 1.0
    @State private var cursorOpacity: Double = 0.0
    @State private var cursorPresentationState: CursyCursorPresentationState = .restingArrow
    @State private var cursorMotionReducer = CursyCursorMotionReducer()

    // MARK: - Buddy Navigation State

    /// The buddy's current behavioral mode (following cursor, navigating, or pointing).
    @State private var buddyNavigationMode: BuddyNavigationMode = .followingCursor

    /// Speech bubble text shown when pointing at a detected element.
    @State private var navigationBubbleText: String = ""
    @State private var navigationBubbleOpacity: Double = 0.0
    @State private var navigationBubbleSize: CGSize = .zero

    /// The cursor position at the moment navigation started, used to detect
    /// if the user moves the cursor enough to cancel the navigation.
    @State private var cursorPositionWhenNavigationStarted: CGPoint = .zero

    /// Timer driving the frame-by-frame bezier arc flight animation.
    /// Invalidated when the flight completes, is canceled, or the view disappears.
    @State private var navigationAnimationTimer: Timer?

    /// Scale factor for the navigation speech bubble's pop-in entrance.
    /// Starts at 0.5 and springs to 1.0 when the first character appears.
    @State private var navigationBubbleScale: CGFloat = 1.0

    /// True when the buddy is flying BACK to the cursor after pointing.
    /// Only during the return flight can cursor movement cancel the animation.
    @State private var isReturningToCursor: Bool = false

    // MARK: - Onboarding Video Layout

    private let onboardingVideoPlayerWidth: CGFloat = 330
    private let onboardingVideoPlayerHeight: CGFloat = 186

    private let fullWelcomeMessage = "hey! i'm cursy"

    private let navigationPointerPhrases = [
        "right here!",
        "this one!",
        "over here!",
        "click this!",
        "here it is!",
        "found it!"
    ]

    var body: some View {
        ZStack {
            // Nearly transparent background (helps with compositing)
            Color.black.opacity(0.001)

            // Welcome speech bubble (first launch only)
            if isCursorOnThisScreen && showWelcome && !welcomeText.isEmpty {
                Text(welcomeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DS.Colors.overlayCursorBlue)
                            .shadow(color: DS.Colors.overlayCursorBlue.opacity(0.5), radius: 6, x: 0, y: 0)
                    )
                    .fixedSize()
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: SizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .opacity(bubbleOpacity)
                    .position(x: cursorPosition.x + 10 + (bubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.5), value: bubbleOpacity)
                    .onPreferenceChange(SizePreferenceKey.self) { newSize in
                        bubbleSize = newSize
                    }
            }

            // Onboarding video — always in the view tree so opacity animation works
            // reliably. When no player exists or opacity is 0, nothing is visible.
            // allowsHitTesting(false) prevents it from intercepting clicks.
            OnboardingVideoPlayerView(player: companionManager.onboardingVideoPlayer)
                .frame(width: onboardingVideoPlayerWidth, height: onboardingVideoPlayerHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(0.4 * companionManager.onboardingVideoOpacity), radius: 12, x: 0, y: 6)
                .opacity(isCursorOnThisScreen ? companionManager.onboardingVideoOpacity : 0)
                .position(
                    x: cursorPosition.x + 10 + (onboardingVideoPlayerWidth / 2),
                    y: cursorPosition.y + 18 + (onboardingVideoPlayerHeight / 2)
                )
                .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                .animation(.easeInOut(duration: 2.0), value: companionManager.onboardingVideoOpacity)
                .allowsHitTesting(false)

            // Onboarding prompt — "press control + option and say hi" streamed after video ends
            if isCursorOnThisScreen && companionManager.showOnboardingPrompt && !companionManager.onboardingPromptText.isEmpty {
                Text(companionManager.onboardingPromptText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DS.Colors.overlayCursorBlue)
                            .shadow(color: DS.Colors.overlayCursorBlue.opacity(0.5), radius: 6, x: 0, y: 0)
                    )
                    .fixedSize()
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: SizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .opacity(companionManager.onboardingPromptOpacity)
                    .position(x: cursorPosition.x + 10 + (bubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.easeOut(duration: 0.4), value: companionManager.onboardingPromptOpacity)
                    .onPreferenceChange(SizePreferenceKey.self) { newSize in
                        bubbleSize = newSize
                    }
            }

            // Navigation pointer bubble — shown when buddy arrives at a detected element.
            // Pops in with a scale-bounce (0.5x → 1.0x spring) and a bright initial
            // glow that settles, creating a "materializing" effect.
            if buddyNavigationMode == .pointingAtTarget && !navigationBubbleText.isEmpty
                && (companionManager.visualAnnotation?.style ?? .cursor) == .cursor {
                Text(navigationBubbleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DS.Colors.overlayCursorBlue)
                            .shadow(
                                color: DS.Colors.overlayCursorBlue.opacity(0.5 + (1.0 - navigationBubbleScale) * 1.0),
                                radius: 6 + (1.0 - navigationBubbleScale) * 16,
                                x: 0, y: 0
                            )
                    )
                    .fixedSize()
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: NavigationBubbleSizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .scaleEffect(navigationBubbleScale)
                    .opacity(navigationBubbleOpacity)
                    .position(x: cursorPosition.x + 10 + (navigationBubbleSize.width / 2), y: cursorPosition.y + 18)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0), value: cursorPosition)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: navigationBubbleScale)
                    .animation(.easeOut(duration: 0.5), value: navigationBubbleOpacity)
                    .onPreferenceChange(NavigationBubbleSizePreferenceKey.self) { newSize in
                        navigationBubbleSize = newSize
                    }
            }

            if let annotation = companionManager.visualAnnotation,
               annotation.style != .cursor, annotation.displayFrame == screenFrame {
                VisualAnnotationView(annotation: annotation,
                    elapsed: playingAnnotationID == annotation.id ? annotationElapsed : 0,
                    pointer: annotationPointer)
                    .opacity(annotationOpacity)
            }

            SpatialTrailView(recorder: companionManager.spatialContextRecorder,
                             screenFrame: screenFrame,
                             spanish: companionManager.preferredLanguage == .spanish,
                             isListening: companionManager.voiceState == .listening,
                             hintAnchor: companionManager.homeSpatialHintAnchor)

            // One persistent glass surface communicates every voice state.
            //
            // During cursor following: fast spring animation for snappy tracking.
            // During navigation: NO implicit animation — the frame-by-frame bezier
            // timer controls position directly at 60fps for a smooth arc flight.
            cursorVisual
                .scaleEffect(notchClickScale)
                .opacity(buddyIsVisibleOnThisScreen ? cursorOpacity : 0)
                .position(cursorPosition)
                .animation(
                    buddyNavigationMode == .followingCursor && notchFlightPhase == .following
                        ? .spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0)
                        : nil,
                    value: cursorPosition
                )

        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .ignoresSafeArea()
        .onAppear {
            // Set initial cursor position immediately before starting animation
            let mouseLocation = NSEvent.mouseLocation
            isCursorOnThisScreen = screenFrame.contains(mouseLocation)

            let swiftUIPosition = convertScreenPointToSwiftUICoordinates(mouseLocation)
            self.cursorPosition = CGPoint(x: swiftUIPosition.x + 35, y: swiftUIPosition.y + 25)
            self.cursorMotionReducer.reset(
                position: swiftUIPosition,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            self.cursorPresentationState = .restingArrow

            startTrackingCursor()

            // Only show welcome message on first appearance (app start)
            // and only if the cursor starts on this screen
            if isFirstAppearance && isCursorOnThisScreen {
                withAnimation(.easeIn(duration: 2.0)) {
                    self.cursorOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    guard self.showWelcome else { return }
                    self.bubbleOpacity = 0.0
                    startWelcomeAnimation()
                }
            } else {
                self.cursorOpacity = 1.0
            }
            synchronizeNotchPresentation()
        }
        .onDisappear {
            if companionManager.visualAnnotation?.displayFrame == screenFrame {
                companionManager.clearDetectedElementLocation()
            }
            navigationRevision = UUID()
            notchClickTask?.cancel()
            timer?.invalidate()
            navigationAnimationTimer?.invalidate()
            companionManager.tearDownOnboardingVideo()
        }
        .onChange(of: companionManager.voiceState) { synchronizeNotchPresentation() }
        .onChange(of: companionManager.voiceNotchAnchor) { synchronizeNotchPresentation() }
        .onChange(of: companionManager.voiceNotchActivationID) { synchronizeNotchPresentation() }
        .task(id: "\(companionManager.visualAnnotation?.id.uuidString ?? "none")-\(reduceMotion)") {
            await playAnnotation()
        }
        .onChange(of: companionManager.detectedElementScreenLocation) { newLocation in
            if newLocation == nil {
                navigationRevision = UUID()
                navigationAnimationTimer?.invalidate()
                navigationAnimationTimer = nil
                buddyNavigationMode = .followingCursor
                navigationBubbleText = ""
                navigationBubbleOpacity = 0
                navigationBubbleScale = 1
                isReturningToCursor = false
                cursorPresentationState = .restingArrow
                // A new recording clears the previous target before publishing its voice state.
                if notchFlightPhase != .following { notchFlightPhase = .following }
                synchronizeNotchPresentation()
                return
            }
            if shouldDockAtNotch { synchronizeNotchPresentation(); return }
            // When a UI element location is detected, navigate the buddy to
            // that position so it points at the element.
            guard let screenLocation = newLocation,
                  let displayFrame = companionManager.detectedElementDisplayFrame else {
                return
            }

            // Only navigate if the target is on THIS screen
            guard screenFrame.contains(CGPoint(x: displayFrame.midX, y: displayFrame.midY))
                  || displayFrame == screenFrame else {
                return
            }

            startNavigatingToElement(screenLocation: screenLocation)
        }
    }

    /// Whether the buddy triangle should be visible on this screen.
    /// True when cursor is on this screen during normal following, or
    /// when navigating/pointing at a target on this screen. When another
    /// screen is navigating (detectedElementScreenLocation is set but this
    /// screen isn't the one animating), hide the cursor so only one buddy
    /// is ever visible at a time.
    private var buddyIsVisibleOnThisScreen: Bool {
        if shouldDockAtNotch {
            return companionManager.voiceNotchAnchor?.displayFrame == screenFrame &&
                (notchFlightPhase == .entering || notchFlightPhase == .clicking)
        }
        if notchFlightPhase == .docked { return false }
        switch buddyNavigationMode {
        case .followingCursor:
            // If another screen's BlueCursorView is navigating to an element,
            // hide the cursor on this screen to prevent a duplicate buddy
            if companionManager.detectedElementScreenLocation != nil {
                return companionManager.visualAnnotation?.style != .cursor
                    && companionManager.visualAnnotation != nil
                    && companionManager.annotationArtistID == nil && isCursorOnThisScreen
            }
            return isCursorOnThisScreen
        case .navigatingToTarget, .pointingAtTarget:
            return true
        }
    }

    @ViewBuilder
    private var cursorVisual: some View {
            CursyGlassCursorView(
                presentationState: cursorPresentationState,
                voiceState: buddyNavigationMode == .followingCursor && notchFlightPhase == .following ? companionManager.voiceState : .idle,
                audioPowerLevel: companionManager.currentAudioPowerLevel,
                isVisible: buddyIsVisibleOnThisScreen && cursorOpacity > 0
            )
    }

    // MARK: - Cursor Tracking

    private func startTrackingCursor() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            let mouseLocation = NSEvent.mouseLocation
            self.isCursorOnThisScreen = self.screenFrame.contains(mouseLocation)
            // This timer is installed on the main run loop by the view.
            MainActor.assumeIsolated {
                if self.companionManager.visualAnnotation?.displayFrame == self.screenFrame {
                    self.annotationPointer = self.convertScreenPointToSwiftUICoordinates(mouseLocation)
                }
            }
            if self.notchFlightPhase != .following || self.shouldDockAtNotch { return }

            // During forward flight or pointing, the buddy is NOT interrupted by
            // mouse movement — it completes its full animation and return flight.
            // Only during the RETURN flight do we allow cursor movement to cancel
            // (so the buddy snaps to following if the user moves while it's flying back).
            if self.buddyNavigationMode == .navigatingToTarget && self.isReturningToCursor {
                let currentMouseInSwiftUI = self.convertScreenPointToSwiftUICoordinates(mouseLocation)
                let distanceFromNavigationStart = hypot(
                    currentMouseInSwiftUI.x - self.cursorPositionWhenNavigationStarted.x,
                    currentMouseInSwiftUI.y - self.cursorPositionWhenNavigationStarted.y
                )
                if distanceFromNavigationStart > 100 {
                    cancelNavigationAndResumeFollowing()
                }
                return
            }

            // During forward navigation or pointing, just skip cursor tracking
            if self.buddyNavigationMode != .followingCursor {
                return
            }

            // Normal cursor following
            let swiftUIPosition = self.convertScreenPointToSwiftUICoordinates(mouseLocation)
            self.cursorPresentationState = self.cursorMotionReducer.update(
                position: swiftUIPosition,
                timestamp: ProcessInfo.processInfo.systemUptime
            )
            let buddyX = swiftUIPosition.x + 35
            let buddyY = swiftUIPosition.y + 25
            self.cursorPosition = CGPoint(x: buddyX, y: buddyY)
        }
    }

    /// Converts a macOS screen point (AppKit, bottom-left origin) to SwiftUI
    /// coordinates (top-left origin) relative to this screen's overlay window.
    private func convertScreenPointToSwiftUICoordinates(_ screenPoint: CGPoint) -> CGPoint {
        ScreenCoordinateSpace.overlayPoint(globalPoint: screenPoint, displayFrame: screenFrame)
    }

    // Presentation only: the microphone and the physical pointer never wait for this flight.
    private var shouldDockAtNotch: Bool {
        companionManager.voiceNotchAnchor != nil && HomeNotchInteraction.shouldDock(
            voiceState: companionManager.voiceState,
            hasValidatedTarget: companionManager.detectedElementScreenLocation != nil)
    }

    private func synchronizeNotchPresentation() {
        if shouldDockAtNotch, let anchor = companionManager.voiceNotchAnchor {
            let activationID = companionManager.voiceNotchActivationID
            if notchActivationID == activationID &&
                (notchFlightPhase == .entering || notchFlightPhase == .clicking || notchFlightPhase == .docked) { return }
            notchActivationID = activationID
            notchClickTask?.cancel()
            notchClickScale = 1
            navigationRevision = UUID()
            navigationAnimationTimer?.invalidate()
            navigationBubbleText = ""
            navigationBubbleOpacity = 0
            buddyNavigationMode = .followingCursor
            isReturningToCursor = false
            guard anchor.displayFrame == screenFrame else { return }
            showWelcome = false
            notchFlightPhase = .entering
            cursorPresentationState = .travelingComet
            let revision = navigationRevision
            let destination = convertScreenPointToSwiftUICoordinates(anchor.activationPoint)
            animateBezierFlightArc(to: destination, duration: HomeNotchInteraction.arrivalDuration, notchCurve: true) {
                guard revision == self.navigationRevision, self.shouldDockAtNotch else { return }
                self.notchFlightPhase = .clicking
                self.cursorPresentationState = .pointingArrow
                self.notchClickTask = Task { @MainActor in
                    if !reduceMotion {
                        withAnimation(.easeOut(duration: HomeNotchInteraction.clickDuration)) { notchClickScale = 0.82 }
                        do { try await Task.sleep(for: .seconds(HomeNotchInteraction.clickDuration)) } catch { return }
                    }
                    guard !Task.isCancelled, revision == navigationRevision,
                          shouldDockAtNotch, activationID == companionManager.voiceNotchActivationID else { return }
                    withAnimation(.easeOut(duration: 0.14)) { notchClickScale = 1 }
                    companionManager.voiceNotchActivatedID = activationID
                    let hidden = convertScreenPointToSwiftUICoordinates(anchor.hiddenCursorPoint)
                    animateBezierFlightArc(to: hidden, duration: 0.18) {
                        guard revision == navigationRevision, shouldDockAtNotch else { return }
                        notchFlightPhase = .docked
                    }
                }
            }
            return
        }
        guard notchFlightPhase == .entering || notchFlightPhase == .clicking || notchFlightPhase == .docked else { return }
        notchClickTask?.cancel()
        notchClickScale = 1
        if let target = companionManager.detectedElementScreenLocation,
           companionManager.detectedElementDisplayFrame == screenFrame {
            startNavigatingToElement(screenLocation: target)
            return
        }
        navigationRevision = UUID()
        let revision = navigationRevision
        notchClickTask?.cancel()
        notchClickScale = 1
        notchFlightPhase = .leaving
        let mouse = convertScreenPointToSwiftUICoordinates(NSEvent.mouseLocation)
        let destination = CGPoint(x: mouse.x + 35, y: mouse.y + 25)
        animateBezierFlightArc(to: destination, duration: HomeNotchInteraction.duration) {
            guard revision == self.navigationRevision else { return }
            self.notchFlightPhase = .following
            self.cursorPresentationState = .restingArrow
            self.cursorMotionReducer.reset(position: mouse, timestamp: ProcessInfo.processInfo.systemUptime)
        }
    }

    // MARK: - Element Navigation

    /// Starts animating the buddy toward a detected UI element location.
    private func startNavigatingToElement(screenLocation: CGPoint) {
        // Geometric tools own one coordinated ink/cursor clock, not the legacy flight.
        if let annotation = companionManager.visualAnnotation, annotation.style != .cursor { return }
        // Don't interrupt welcome animation
        guard !showWelcome || welcomeText.isEmpty else { return }
        notchClickTask?.cancel()
        notchClickScale = 1
        navigationRevision = UUID()
        let revision = navigationRevision
        let leavingNotch = notchFlightPhase != .following
        notchFlightPhase = .following

        // Convert the AppKit screen location to SwiftUI coordinates for this screen
        let targetInSwiftUI = convertScreenPointToSwiftUICoordinates(screenLocation)

        // Offset the target so the buddy sits beside the element rather than
        // directly on top of it — 8px to the right, 12px below.
        let offsetTarget = CGPoint(
            x: targetInSwiftUI.x + 8,
            y: targetInSwiftUI.y + 12
        )

        // Clamp target to screen bounds with padding
        let clampedTarget = CGPoint(
            x: max(20, min(offsetTarget.x, screenFrame.width - 20)),
            y: max(20, min(offsetTarget.y, screenFrame.height - 20))
        )

        // Record the current cursor position so we can detect if the user
        // moves the mouse enough to cancel the return flight
        let mouseLocation = NSEvent.mouseLocation
        cursorPositionWhenNavigationStarted = convertScreenPointToSwiftUICoordinates(mouseLocation)

        // Enter navigation mode — stop cursor following
        buddyNavigationMode = .navigatingToTarget
        isReturningToCursor = false
        cursorPresentationState = .travelingComet

        animateBezierFlightArc(to: clampedTarget, duration: leavingNotch ? HomeNotchInteraction.duration : nil) {
            guard revision == self.navigationRevision, self.buddyNavigationMode == .navigatingToTarget else { return }
            self.startPointingAtElement()
        }
    }

    @MainActor private func playAnnotation() async {
        let playbackRevision = UUID()
        annotationPlaybackRevision = playbackRevision
        if let oldArtist = playingAnnotationID, companionManager.annotationArtistID == oldArtist {
            companionManager.annotationArtistID = nil
        }
        if playingAnnotationID != nil {
            buddyNavigationMode = .followingCursor
            notchClickScale = 1
        }
        playingAnnotationID = nil
        guard let annotation = companionManager.visualAnnotation, annotation.displayFrame == screenFrame else { return }
        if annotation.style == .cursor {
            if !shouldDockAtNotch { startNavigatingToElement(screenLocation: annotation.point) }
            return
        }
        let identity = annotation.id
        playingAnnotationID = identity
        annotationElapsed = 0
        annotationOpacity = 1
        navigationRevision = UUID()
        navigationAnimationTimer?.invalidate()
        notchClickTask?.cancel()
        notchFlightPhase = .following
        notchClickScale = 1
        navigationBubbleText = ""
        navigationBubbleOpacity = 0
        showWelcome = false
        isReturningToCursor = false
        let draws = annotation.style != .label && !reduceMotion
        companionManager.annotationArtistID = draws ? identity : nil
        buddyNavigationMode = draws ? .navigatingToTarget : .followingCursor
        cursorPresentationState = .pointingArrow
        let drawing = AnnotationDrawing(annotation: annotation)
        let source = cursorPosition
        let first = VisualAnnotationMotion.cursorCenter(tip: drawing.tip(progress: 0))
        let last = VisualAnnotationMotion.cursorCenter(tip: drawing.tip(progress: 1))
        var returnDestination: CGPoint?
        let duration = draws ? VisualAnnotationMotion.total
            : (reduceMotion ? 0.15 : VisualAnnotationMotion.caption + VisualAnnotationMotion.typingDuration(annotation.label))
        let started = ProcessInfo.processInfo.systemUptime
        defer {
            // A cancelled task must never reset the replacement's cursor or frame clock.
            if companionManager.visualAnnotation?.id == identity, annotationPlaybackRevision == playbackRevision {
                notchClickScale = 1
                buddyNavigationMode = .followingCursor
                companionManager.annotationArtistID = nil
            }
        }
        do {
            while true {
                try Task.checkCancellation()
                guard companionManager.visualAnnotation?.id == identity else { return }
                let elapsed = min(duration, ProcessInfo.processInfo.systemUptime - started)
                annotationElapsed = elapsed
                if draws {
                    if elapsed < VisualAnnotationMotion.approach {
                        cursorPosition = VisualAnnotationMotion.curve(from: source, to: first,
                            progress: elapsed / VisualAnnotationMotion.approach)
                    } else if elapsed < VisualAnnotationMotion.drawingStart {
                        cursorPosition = first
                        let press = VisualAnnotationMotion.progress(elapsed, start: VisualAnnotationMotion.approach,
                                                                     duration: VisualAnnotationMotion.press)
                        notchClickScale = 1 - 0.08 * sin(press * .pi)
                    } else if elapsed <= VisualAnnotationMotion.drawingEnd {
                        notchClickScale = 1
                        cursorPosition = VisualAnnotationMotion.cursorCenter(tip: drawing.tip(
                            progress: VisualAnnotationMotion.inkProgress(elapsed, reducedMotion: false)))
                    } else if elapsed < VisualAnnotationMotion.drawingEnd + VisualAnnotationMotion.release {
                        cursorPosition = last
                    } else {
                        if returnDestination == nil {
                            let pointer = convertScreenPointToSwiftUICoordinates(NSEvent.mouseLocation)
                            returnDestination = CGPoint(x: pointer.x + 35, y: pointer.y + 25)
                        }
                        cursorPosition = VisualAnnotationMotion.curve(from: last, to: returnDestination ?? last,
                            progress: VisualAnnotationMotion.progress(elapsed,
                                start: VisualAnnotationMotion.drawingEnd + VisualAnnotationMotion.release,
                                duration: VisualAnnotationMotion.departure))
                    }
                }
                if elapsed >= duration { break }
                try await Task.sleep(for: .milliseconds(16))
            }
            buddyNavigationMode = .followingCursor
            companionManager.annotationArtistID = nil
            // Same short-lived indication semantics as the original pointer bubble.
            // Retirement is not evidence that the user completed an action.
            try await Task.sleep(for: .seconds(4))
            try Task.checkCancellation()
            guard companionManager.visualAnnotation?.id == identity else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.28)) { annotationOpacity = 0 }
            try await Task.sleep(for: .seconds(reduceMotion ? 0.15 : 0.28))
            try Task.checkCancellation()
            guard companionManager.visualAnnotation?.id == identity else { return }
            companionManager.clearDetectedElementLocation()
        } catch { return }
    }

    /// Animates the buddy along a quadratic bezier arc from its current position
    /// to the specified destination. The droplet retains its fixed orientation;
    /// only its position follows the curve.
    private func animateBezierFlightArc(
        to destination: CGPoint,
        duration: TimeInterval? = nil,
        notchCurve: Bool = false,
        onComplete: @escaping () -> Void
    ) {
        navigationAnimationTimer?.invalidate()
        if reduceMotion {
            cursorPosition = destination
            onComplete()
            return
        }

        let startPosition = cursorPosition
        let endPosition = destination

        let deltaX = endPosition.x - startPosition.x
        let deltaY = endPosition.y - startPosition.y
        let distance = hypot(deltaX, deltaY)

        // Flight duration scales with distance: short hops are quick, long
        // flights are more dramatic. Clamped to 0.6s–1.4s.
        let flightDurationSeconds = duration ?? min(max(distance / 800.0, 0.6), 1.4)
        let frameInterval: Double = 1.0 / 60.0
        let startedAt = ProcessInfo.processInfo.systemUptime

        // Control point for the quadratic bezier arc. Offset the midpoint
        // upward (negative Y in SwiftUI) so the buddy flies in a parabolic arc.
        let midPoint = CGPoint(
            x: (startPosition.x + endPosition.x) / 2.0,
            y: (startPosition.y + endPosition.y) / 2.0
        )
        let arcHeight = min(distance * 0.2, 80.0)
        let controlPoint = CGPoint(x: midPoint.x, y: midPoint.y - arcHeight)

        navigationAnimationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { _ in
            let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            if elapsed >= flightDurationSeconds {
                self.navigationAnimationTimer?.invalidate()
                self.navigationAnimationTimer = nil
                self.cursorPosition = endPosition
                onComplete()
                return
            }

            // Linear progress 0→1 over the flight duration
            let linearProgress = elapsed / flightDurationSeconds

            // Smoothstep easeInOut: 3t² - 2t³ (Hermite interpolation)
            let t = linearProgress * linearProgress * (3.0 - 2.0 * linearProgress)
            if notchCurve {
                self.cursorPosition = HomeNotchInteraction.arrivalPoint(from: startPosition, to: endPosition, progress: t)
                return
            }

            // Quadratic bezier: B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
            let oneMinusT = 1.0 - t
            let bezierX = oneMinusT * oneMinusT * startPosition.x
                        + 2.0 * oneMinusT * t * controlPoint.x
                        + t * t * endPosition.x
            let bezierY = oneMinusT * oneMinusT * startPosition.y
                        + 2.0 * oneMinusT * t * controlPoint.y
                        + t * t * endPosition.y

            self.cursorPosition = CGPoint(x: bezierX, y: bezierY)

        }
    }

    /// Transitions to pointing mode — shows a speech bubble with a bouncy
    /// scale-in entrance and variable-speed character streaming.
    private func startPointingAtElement() {
        let revision = navigationRevision
        buddyNavigationMode = .pointingAtTarget
        cursorPresentationState = .pointingArrow

        // Reset navigation bubble state — start small for the scale-bounce entrance
        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0
        navigationBubbleSize = .zero
        navigationBubbleScale = 0.5

        // Use custom bubble text from the companion manager (e.g. onboarding demo)
        // if available, otherwise fall back to a random pointer phrase
        let pointerPhrase = companionManager.detectedElementBubbleText
            ?? navigationPointerPhrases.randomElement()
            ?? "right here!"

        // Give the comet-to-arrow morph one micro-beat to resolve before the
        // pointing copy appears, so the target gesture reads clearly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard revision == self.navigationRevision, self.buddyNavigationMode == .pointingAtTarget else { return }
            self.navigationBubbleOpacity = 1.0
            self.streamNavigationBubbleCharacter(phrase: pointerPhrase, characterIndex: 0, revision: revision) {
                // All characters streamed — hold for 3 seconds, then fly back
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    guard revision == self.navigationRevision, self.buddyNavigationMode == .pointingAtTarget else { return }
                    self.navigationBubbleOpacity = 0.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard revision == self.navigationRevision, self.buddyNavigationMode == .pointingAtTarget else { return }
                        self.startFlyingBackToCursor()
                    }
                }
            }
        }
    }

    /// Streams the navigation bubble text one character at a time with variable
    /// delays (30–60ms) for a natural "speaking" rhythm.
    private func streamNavigationBubbleCharacter(
        phrase: String,
        characterIndex: Int,
        revision: UUID,
        onComplete: @escaping () -> Void
    ) {
        guard revision == navigationRevision, buddyNavigationMode == .pointingAtTarget else { return }
        guard characterIndex < phrase.count else {
            onComplete()
            return
        }

        let charIndex = phrase.index(phrase.startIndex, offsetBy: characterIndex)
        navigationBubbleText.append(phrase[charIndex])

        // On the first character, trigger the scale-bounce entrance
        if characterIndex == 0 {
            navigationBubbleScale = 1.0
        }

        let characterDelay = Double.random(in: 0.03...0.06)
        DispatchQueue.main.asyncAfter(deadline: .now() + characterDelay) {
            self.streamNavigationBubbleCharacter(
                phrase: phrase,
                characterIndex: characterIndex + 1,
                revision: revision,
                onComplete: onComplete
            )
        }
    }

    /// Flies the buddy back to the current cursor position after pointing is done.
    private func startFlyingBackToCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let cursorInSwiftUI = convertScreenPointToSwiftUICoordinates(mouseLocation)
        let cursorWithTrackingOffset = CGPoint(x: cursorInSwiftUI.x + 35, y: cursorInSwiftUI.y + 25)

        cursorPositionWhenNavigationStarted = cursorInSwiftUI

        buddyNavigationMode = .navigatingToTarget
        isReturningToCursor = true
        cursorPresentationState = .travelingComet

        animateBezierFlightArc(to: cursorWithTrackingOffset) {
            self.finishNavigationAndResumeFollowing()
        }
    }

    /// Cancels an in-progress navigation because the user moved the cursor.
    private func cancelNavigationAndResumeFollowing() {
        navigationRevision = UUID()
        navigationAnimationTimer?.invalidate()
        navigationAnimationTimer = nil
        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0
        navigationBubbleScale = 1.0
        finishNavigationAndResumeFollowing()
    }

    /// Returns the buddy to normal cursor-following mode after navigation completes.
    private func finishNavigationAndResumeFollowing() {
        navigationAnimationTimer?.invalidate()
        navigationAnimationTimer = nil
        buddyNavigationMode = .followingCursor
        isReturningToCursor = false
        let mouseLocation = NSEvent.mouseLocation
        let cursorInSwiftUI = convertScreenPointToSwiftUICoordinates(mouseLocation)
        cursorMotionReducer.reset(
            position: cursorInSwiftUI,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        cursorPresentationState = .restingArrow
        navigationBubbleText = ""
        navigationBubbleOpacity = 0.0
        navigationBubbleScale = 1.0
        companionManager.clearDetectedElementLocation()
    }

    // MARK: - Welcome Animation

    private func startWelcomeAnimation() {
        withAnimation(.easeIn(duration: 0.4)) {
            self.bubbleOpacity = 1.0
        }

        var currentIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard self.showWelcome else { timer.invalidate(); return }
            guard currentIndex < self.fullWelcomeMessage.count else {
                timer.invalidate()
                // Hold the text for 2 seconds, then fade it out
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.bubbleOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    guard self.showWelcome else { return }
                    self.showWelcome = false
                    // Start the onboarding video right after the welcome text disappears
                    self.companionManager.setupOnboardingVideo()
                }
                return
            }

            let index = self.fullWelcomeMessage.index(self.fullWelcomeMessage.startIndex, offsetBy: currentIndex)
            self.welcomeText.append(self.fullWelcomeMessage[index])
            currentIndex += 1
        }
    }
}

// Manager for overlay windows — creates one per screen so the cursor
// buddy seamlessly follows the cursor across multiple monitors.
@MainActor
class OverlayWindowManager {
    private var overlayWindows: [OverlayWindow] = []
    private var screenChanges: AnyCancellable?
    var hasShownOverlayBefore = false

    func showOverlay(onScreens screens: [NSScreen], companionManager: CompanionManager) {
        if screenChanges == nil {
            screenChanges = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak companionManager] _ in
                    Task { @MainActor in
                        guard let self, let companionManager, self.isShowingOverlay() else { return }
                        companionManager.clearDetectedElementLocation()
                        self.showOverlay(onScreens: NSScreen.screens, companionManager: companionManager)
                    }
                }
        }
        // Hide any existing overlays
        hideOverlay()

        // Track if this is the first time showing overlay (welcome message)
        let isFirstAppearance = !hasShownOverlayBefore
        hasShownOverlayBefore = true

        // Create one overlay window per screen
        for screen in screens {
            let window = OverlayWindow(screen: screen)

            let contentView = BlueCursorView(
                screenFrame: screen.frame,
                isFirstAppearance: isFirstAppearance,
                companionManager: companionManager
            )

            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = CGRect(origin: .zero, size: screen.frame.size)
            window.contentView = hostingView

            overlayWindows.append(window)
            window.orderFrontRegardless()
        }
    }

    func hideOverlay() {
        for window in overlayWindows {
            window.orderOut(nil)
            window.contentView = nil
        }
        overlayWindows.removeAll()
    }

    /// Fades out overlay windows over `duration` seconds, then removes them.
    func fadeOutAndHideOverlay(duration: TimeInterval = 0.4) {
        let windowsToFade = overlayWindows
        overlayWindows.removeAll()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for window in windowsToFade {
                window.animator().alphaValue = 0
            }
        }, completionHandler: {
            for window in windowsToFade {
                window.orderOut(nil)
                window.contentView = nil
            }
        })
    }

    func isShowingOverlay() -> Bool {
        return !overlayWindows.isEmpty
    }
}

// MARK: - Onboarding Video Player

/// NSViewRepresentable wrapping an AVPlayerLayer so HLS video plays
/// inside SwiftUI. Uses a custom NSView subclass to keep the player
/// layer sized to the view's bounds automatically.
private struct OnboardingVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerNSView {
        let view = AVPlayerNSView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerNSView, context: Context) {
        nsView.player = player
    }
}

private class AVPlayerNSView: NSView {
    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }

    private let playerLayer = AVPlayerLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
