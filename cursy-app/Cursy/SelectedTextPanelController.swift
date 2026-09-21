import AppKit
import ApplicationServices
import Combine
import SwiftUI
import os


@MainActor
private final class SelectionEditorModel: ObservableObject {
    @Published var editing = false
    @Published var draft = ""
    @Published var surfaceScale: CGFloat = 1
    @Published var surfaceOffset: CGFloat = 0
    @Published var editorOpacity: Double = 1
}

@MainActor
final class SelectedTextPanelController {
    private let manager: CompanionManager
    var onOpenChat: (() -> Void)?
    private var selection: AccessibleSelection?
    private var panel: CursyEditingPanel?
    private var notificationPanel: NSPanel?
    private var model = SelectionEditorModel()
    private var eventMonitor: Any?
    private var localMonitor: Any?
    private var workspaceObserver: NSObjectProtocol?
    private let reader = SelectedTextReader()
    private var readTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var readLifecycle = SelectionReadLifecycle()
    private var gestureAnchor: SelectionGestureAnchor?
    private var mouseDownAnchor: (point: CGPoint, processID: pid_t)?
    private var selectionObserver: AXObserver?
    private var observedApplication: AXUIElement?
    private var observedFocus: AXUIElement?
    private var subscriptions = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "Cursy", category: "SelectedText")

    init(manager: CompanionManager) { self.manager = manager }
    deinit {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        readTask?.cancel()
        preparationTask?.cancel()
        if let selectionObserver { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(selectionObserver), .commonModes) }
    }
    func start() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .leftMouseDown, .keyDown, .keyUp, .scrollWheel]) { [weak self] event in
            guard let self else { return }
            if event.type == .leftMouseDown || event.type == .scrollWheel || event.type == .keyDown { self.hide() }
            if event.type == .leftMouseDown, let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier {
                self.mouseDownAnchor = (NSEvent.mouseLocation, processID)
            }
            if event.type == .keyDown && event.keyCode == 53 {
                self.hide()
                if self.manager.conversationSession.selectedText != nil { self.manager.cancelCurrentInteraction() }
            }
            if event.type == .leftMouseUp {
                if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
                    self.gestureAnchor = SelectionGestureAnchor(point: NSEvent.mouseLocation, processID: pid,
                        timestamp: ProcessInfo.processInfo.systemUptime,
                        startPoint: self.mouseDownAnchor?.processID == pid ? self.mouseDownAnchor?.point : nil)
                }
                self.mouseDownAnchor = nil
                self.scheduleRead(pointer: NSEvent.mouseLocation, newGesture: true)
            } else if event.type == .keyUp && (event.modifierFlags.contains(.shift) ||
                [0, 123, 124, 125, 126].contains(Int(event.keyCode))) {
                self.scheduleRead(pointer: nil, newGesture: true)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 {
                self?.hide()
                if self?.manager.conversationSession.selectedText != nil { self?.manager.cancelCurrentInteraction() }
            }
            return event
        }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated {
                self?.hide()
                self?.observeActiveSelection()
            } }
        observeActiveSelection()
        logger.info("Selection monitors installed: events=\(self.eventMonitor != nil, privacy: .public), accessibility=\(AXIsProcessTrusted(), privacy: .public)")
        manager.$voiceState.combineLatest(manager.$homeSpatialHintAnchor).receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.updateVoiceNotification() }.store(in: &subscriptions)
    }
    private func observeActiveSelection() {
        preparationTask?.cancel()
        if let selectionObserver { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(selectionObserver), .commonModes) }
        selectionObserver = nil
        observedApplication = nil
        observedFocus = nil
        guard AXIsProcessTrusted(), let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              processID != ProcessInfo.processInfo.processIdentifier else { return }
        preparationTask = Task { [reader] in _ = await reader.prepare(processID: processID) }
        var observer: AXObserver?
        let result = AXObserverCreate(processID, { _, _, notification, context in
            guard let context else { return }
            let controller = Unmanaged<SelectedTextPanelController>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                guard (controller.panel == nil || !controller.model.editing), NSEvent.pressedMouseButtons == 0 else { return }
                let anchor = controller.gestureAnchor
                let pointer = anchor?.resolve(processID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                    now: ProcessInfo.processInfo.systemUptime)
                if (notification as String) == (kAXFocusedUIElementChangedNotification as String) {
                    controller.observeFocusedSelection()
                }
                controller.scheduleRead(pointer: pointer)
            }
        }, &observer)
        guard result == .success, let observer else { return }
        selectionObserver = observer
        let application = AXUIElementCreateApplication(processID)
        observedApplication = application
        AXUIElementSetMessagingTimeout(application, 0.035)
        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, application, kAXFocusedUIElementChangedNotification as CFString, context)
        AXObserverAddNotification(observer, application, kAXSelectedTextChangedNotification as CFString, context)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observeFocusedSelection()
    }
    private func observeFocusedSelection() {
        guard let selectionObserver, let observedApplication else { return }
        if let observedFocus {
            AXObserverRemoveNotification(selectionObserver, observedFocus, kAXSelectedTextChangedNotification as CFString)
        }
        observedFocus = nil
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(observedApplication, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return }
        let focused = value as! AXUIElement
        AXUIElementSetMessagingTimeout(focused, 0.035)
        observedFocus = focused
        AXObserverAddNotification(selectionObserver, focused, kAXSelectedTextChangedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque())
    }
    private func scheduleRead(pointer: CGPoint?, newGesture: Bool = false) {
        logger.debug("Selection trigger: idle=\(self.manager.voiceState == .idle, privacy: .public), pointer=\(pointer != nil, privacy: .public)")
        // AX can notify just before mouse-up. The concrete gesture supersedes
        // that probe so its confirmed anchor isn't lost; later AX bursts coalesce.
        if newGesture {
            readLifecycle.invalidate()
            readTask?.cancel()
            readTask = nil
        }
        guard manager.voiceState == .idle,
              let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              processID != ProcessInfo.processInfo.processIdentifier,
              let generation = readLifecycle.begin() else { return }
        let desktopTop = NSScreen.screens.first?.frame.maxY ?? 0
        let gestureStart = pointer == nil ? nil : gestureAnchor?.startPoint
        readTask = Task { [weak self, reader] in
            let selection = await reader.read(processID: processID, pointer: pointer,
                desktopTop: desktopTop, requestID: generation, gestureStart: gestureStart)
            guard !Task.isCancelled, let self, self.readLifecycle.finish(generation) else { return }
            self.readTask = nil
            guard self.manager.voiceState == .idle,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
            if let selection { self.show(selection) }
            else { self.dismissPanel() }
        }
    }
    private func show(_ selection: AccessibleSelection) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(selection.frame) }),
              let frame = SelectionPopoverLayout.frame(selection: selection.frame,
                size: CGSize(width: manager.preferredLanguage == .spanish ? 160 : 96, height: 32),
                visible: screen.visibleFrame, obstacles: selection.obstacles) else {
            dismissPanel()
            logger.info("Selection pid=\(selection.processID) reason=no-safe-placement")
            return
        }
        if let panel, !model.editing, self.selection?.processID == selection.processID,
           self.selection?.context == selection.context {
            self.selection = selection
            panel.setFrame(frame, display: true)
            return
        }
        dismissPanel()
        self.selection = selection
        model = SelectionEditorModel()
        let panel = CursyEditingPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: SelectionEditorView(model: model, spanish: manager.preferredLanguage == .spanish,
            onEdit: { [weak self] in self?.edit() }, onSubmit: { [weak self] in self?.submit(voice: false) },
            onVoice: { [weak self] in self?.submit(voice: true) }, onClose: { [weak self] in self?.hide() }))
        self.panel = panel
        panel.orderFrontRegardless()
    }
    private func edit() {
        guard let selection, let panel,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == selection.processID,
              let screen = panel.screen,
              let frame = SelectionPopoverLayout.frame(selection: selection.frame, size: CGSize(width: min(370, screen.visibleFrame.width - 24), height: 46),
                visible: screen.visibleFrame, obstacles: selection.obstacles) else { hide(); return }
        let previous = panel.frame
        panel.beginEditing()
        panel.setFrame(frame, display: true)
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let keyboard = NSApp.currentEvent?.type == .keyDown
        let morph = !reduce && !keyboard && abs(previous.midY - frame.midY) < 24
        model.surfaceScale = morph ? previous.width / frame.width : 1
        model.surfaceOffset = morph ? previous.minX - frame.minX : 0
        model.editorOpacity = keyboard ? 1 : 0
        model.editing = true
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, panel === self.panel else { return }
            withAnimation(keyboard ? nil : .timingCurve(0.77, 0, 0.175, 1, duration: 0.25)) {
                self.model.surfaceScale = 1
                self.model.surfaceOffset = 0
            }
            withAnimation(keyboard ? nil : .easeOut(duration: 0.15).delay(morph ? 0.08 : 0)) {
                self.model.editorOpacity = 1
            }
        }
    }
    private func submit(voice: Bool) {
        guard let selection, voice || !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              manager.beginSelectedText(selection.context) else { return }
        let draft = model.draft
        hide()
        if voice {
            manager.homeDrafts[manager.chatLibrary.selectedID] = draft
            manager.startSelectedTextVoice()
        } else {
            _ = manager.sendHomeText(draft)
            onOpenChat?()
        }
    }
    private func hide() {
        gestureAnchor = nil
        mouseDownAnchor = nil
        readLifecycle.invalidate()
        readTask?.cancel()
        readTask = nil
        dismissPanel()
    }
    private func dismissPanel() {
        panel?.endEditing()
        panel?.orderOut(nil)
        panel = nil
        selection = nil
    }
    private func updateVoiceNotification() {
        if manager.voiceState != .idle { hide() }
        guard manager.isSelectionVoiceInteraction,
              let anchor = manager.homeSpatialHintAnchor else {
            notificationPanel?.ignoresMouseEvents = true
            return
        }
        if notificationPanel == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: SelectedTextVoiceCard(manager: manager,
                openChat: { [weak self] in self?.onOpenChat?() }))
            notificationPanel = panel
        }
        let width: CGFloat = min(348, anchor.displayFrame.width - 24)
        guard anchor.slot.minY + 116 <= anchor.displayFrame.height else {
            notificationPanel?.orderOut(nil)
            return
        }
        let frame = CGRect(x: anchor.displayFrame.minX + anchor.slot.midX - width / 2,
            y: anchor.displayFrame.maxY - anchor.slot.minY - 116, width: width, height: 116)
        notificationPanel?.setFrame(frame, display: true)
        notificationPanel?.ignoresMouseEvents = false
        notificationPanel?.orderFrontRegardless()
    }
}

private struct SelectionEditorView: View {
    @ObservedObject var model: SelectionEditorModel
    let spanish: Bool
    let onEdit: () -> Void
    let onSubmit: () -> Void
    let onVoice: () -> Void
    let onClose: () -> Void
    @AppStorage(CursyCursorTint.preferenceKey) private var storedTint = CursyCursorTint.mint.rawValue
    var body: some View {
        Group {
            if model.editing {
                HStack(spacing: 3) {
                    ZStack(alignment: .leading) {
                        if model.draft.isEmpty { Text(spanish ? "Pregunta sobre este texto…" : "Ask about this text…").font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).padding(.leading, 10).allowsHitTesting(false) }
                        HomeMessageEditor(text: $model.draft, placeholder: spanish ? "Pregunta sobre el texto" : "Question about the text", onSubmit: onSubmit, compact: true, focusOnAppearance: true)
                    }
                    Button(action: onVoice) { Image(systemName: "mic") }.help(spanish ? "Hablar del fragmento" : "Talk about this excerpt")
                    Button(action: onSubmit) { Image(systemName: "arrow.up") }.disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).help(spanish ? "Enviar" : "Send")
                    Button(action: onClose) { Image(systemName: "xmark") }.help(spanish ? "Cerrar" : "Close")
                }.padding(.horizontal, 9).padding(.vertical, 4).opacity(model.editorOpacity)
            } else {
                Button(action: onEdit) {
                    Text(spanish ? "Preguntarle a Cursy" : "Ask Cursy").foregroundStyle(.white)
                        .font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .foregroundStyle(CursyCursorTint.resolve(storedTint).color)
        .buttonStyle(.plain).pointerCursor()
        .background {
            RoundedRectangle(cornerRadius: model.editing ? 12 : 9).fill(.black.opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: model.editing ? 12 : 9).stroke(.white.opacity(0.18)))
                .scaleEffect(x: model.surfaceScale, y: 1, anchor: .leading).offset(x: model.surfaceOffset)
        }.environment(\.colorScheme, .dark)
    }
}

private struct SelectedTextVoiceCard: View {
    @ObservedObject var manager: CompanionManager
    let openChat: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var retainedText = ""
    @State private var visible = false
    private var spanish: Bool { manager.preferredLanguage == .spanish }
    private var shouldShow: Bool { manager.isSelectionVoiceInteraction && manager.homeSpatialHintAnchor != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(spanish ? "Solo texto seleccionado" : "Selected text only").font(.system(size: 10))
                Spacer()
                Button(action: openChat) { Image(systemName: "bubble.left.and.bubble.right") }.help(spanish ? "Ver chat" : "Open chat")
                Button(action: manager.cancelCurrentInteraction) { Image(systemName: "xmark") }.help(spanish ? "Terminar" : "Finish")
            }
            Text(retainedText).lineLimit(1).font(.system(size: 12))
            HStack {
                Text(manager.isSelectionGreeting ? (spanish ? "Cursy te da la bienvenida…" : "Cursy is greeting you…") :
                    HomeActivity.resolve(session: manager.conversationSession, voiceState: manager.voiceState, permissionsReady: true).title(isSpanish: spanish))
                Spacer()
                if manager.voiceState == .listening {
                    Button(action: manager.toggleHomeVoice) { Image(systemName: "arrow.up.circle") }.help(spanish ? "Enviar voz" : "Send voice")
                }
            }.font(.system(size: 12))
        }.padding(12).foregroundStyle(.white).background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.14)))
            .buttonStyle(.plain).pointerCursor().padding(.horizontal, 4).padding(.top, 7)
            .offset(y: reduceMotion || visible ? 0 : -110).opacity(visible ? 1 : 0)
            .animation(.timingCurve(0.25, 0.1, 0.25, 1, duration: reduceMotion ? 0.15 : 0.4), value: visible)
            .frame(maxHeight: .infinity, alignment: .top).clipped().allowsHitTesting(visible).accessibilityHidden(!visible)
            .onAppear { update() }.onChange(of: shouldShow) { update() }
            .onChange(of: manager.conversationSession.selectedText) { update() }
    }
    private func update() {
        if let text = manager.conversationSession.selectedText?.text { retainedText = text }
        visible = shouldShow
    }
}
