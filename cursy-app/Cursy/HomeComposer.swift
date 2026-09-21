import AppKit
import SwiftUI

/// Passive panels become key only at an explicit editing action, never on hover.
class CursyEditingPanel: NSPanel {
    var editingAllowed = false
    override var canBecomeKey: Bool { editingAllowed }
    override var canBecomeMain: Bool { false }
    func beginEditing() { editingAllowed = true; makeKey() }
    func endEditing() { makeFirstResponder(nil); resignKey(); editingAllowed = false }
}

struct HomeMessageEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var compact = false
    var focusOnAppearance = false

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let editor = MessageTextView()
        scroll.focusRingType = .none
        editor.focusRingType = .none
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.drawsBackground = false
        editor.textColor = .white
        editor.insertionPointColor = .white
        editor.font = .systemFont(ofSize: 13)
        editor.textContainerInset = NSSize(width: 5, height: compact ? 7 : 9)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.delegate = context.coordinator
        editor.submit = onSubmit
        editor.setAccessibilityLabel(placeholder)
        editor.string = text
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = !compact
        scroll.documentView = editor
        if focusOnAppearance {
            DispatchQueue.main.async { [weak editor] in
                guard let editor, let panel = editor.window as? CursyEditingPanel, panel.isVisible else { return }
                panel.beginEditing()
                panel.makeFirstResponder(editor)
            }
        }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? MessageTextView else { return }
        if editor.string != text, !editor.hasMarkedText() { editor.string = text }
        editor.submit = onSubmit
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HomeMessageEditor
        init(_ parent: HomeMessageEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = String(editor.string.prefix(ConversationSession.textLimit))
        }
    }
    final class MessageTextView: NSTextView {
        var submit: (() -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) {
            (window as? CursyEditingPanel)?.beginEditing()
            super.mouseDown(with: event)
        }
        override func keyDown(with event: NSEvent) {
            if event.keyCode == 36, !event.modifierFlags.contains(.shift), !hasMarkedText() {
                submit?()
            } else { super.keyDown(with: event) }
        }
    }
}

struct HomeComposer: View {
    @ObservedObject var manager: CompanionManager
    @AppStorage(CursyCursorTint.preferenceKey) private var storedTint = CursyCursorTint.mint.rawValue
    private var spanish: Bool { manager.preferredLanguage == .spanish }
    private var draft: Binding<String> { Binding(
        get: { manager.homeDrafts[manager.chatLibrary.selectedID] ?? "" },
        set: { manager.homeDrafts[manager.chatLibrary.selectedID] = $0 }) }
    private var busy: Bool { manager.conversationSession.activeTurnID != nil }
    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                ZStack(alignment: .topLeading) {
                    if draft.wrappedValue.isEmpty {
                        Text(spanish ? "Pregúntale a Cursy…" : "Ask Cursy…")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                            .padding(.top, 9).padding(.leading, 10).allowsHitTesting(false)
                    }
                    HomeMessageEditor(text: draft, placeholder: spanish ? "Mensaje a Cursy" : "Message Cursy", onSubmit: send)
                        .id(manager.chatLibrary.selectedID).frame(height: 52)
                }
                HStack {
                    Button(action: manager.toggleHomeVoice) {
                        Image(systemName: manager.voiceState == .listening ? "stop.circle" : "mic")
                    }.help(spanish ? "Hablar / enviar voz" : "Talk / send voice")
                    Spacer()
                    Text("Enter · Shift + Enter").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    if busy {
                        Button(action: manager.cancelCurrentInteraction) { Image(systemName: "stop.fill") }
                            .help(spanish ? "Detener" : "Stop")
                    } else {
                        Button(action: send) { Image(systemName: "arrow.up") }
                            .disabled(draft.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .help(spanish ? "Enviar" : "Send")
                    }
                }.foregroundStyle(CursyCursorTint.resolve(storedTint).color).padding(.horizontal, 8).padding(.bottom, 8)
            }
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.16)))
            Text(spanish ? "El texto no comparte tu pantalla. Chats temporales." : "Text doesn't share your screen. Temporary chats.")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.8))
        }.buttonStyle(.plain).pointerCursor().padding(.horizontal, 20).padding(.bottom, 16)
    }
    private func send() {
        guard !busy else { return }
        if manager.sendHomeText(draft.wrappedValue) { draft.wrappedValue = "" }
    }
}
