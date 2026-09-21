import AppKit
import Combine

struct HomeKeyboardShortcut: Codable, Equatable {
    static let preferenceKey = "customPushToTalkShortcut"
    let keyCode: UInt16
    let modifiers: UInt
    let title: String
    static var current: Self? {
        guard let data = UserDefaults.standard.data(forKey: preferenceKey) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    static func make(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String) -> Self? {
        let flags = flags.intersection([.control, .option, .command, .shift])
        guard !flags.intersection([.control, .option, .command]).isEmpty,
              ![UInt16(53), 36, 48, 51, 123, 124, 125, 126].contains(keyCode),
              !(flags.contains(.command) && ("qwcvxantl".contains(characters.lowercased()) || keyCode == 49)),
              !(flags == [.control] && keyCode == 49), !characters.isEmpty else { return nil }
        let titles: [(NSEvent.ModifierFlags, String)] = [(.control, "Control"), (.option, "Option"), (.shift, "Shift"), (.command, "Command")]
        let title = (titles.filter { flags.contains($0.0) }.map(\.1) + [keyCode == 49 ? "Space" : characters.uppercased()]).joined(separator: " + ")
        return Self(keyCode: keyCode, modifiers: flags.rawValue, title: title)
    }
    func transition(type: NSEvent.EventType, keyCode: UInt16, flags: NSEvent.ModifierFlags, pressed: Bool) -> BuddyPushToTalkShortcut.ShortcutTransition {
        let matching = flags.intersection([.control, .option, .command, .shift]).rawValue == modifiers
        if pressed && (!matching || (type == .keyUp && keyCode == self.keyCode)) { return .released }
        if !pressed && matching && type == .keyDown && keyCode == self.keyCode { return .pressed }
        return .none
    }
}

@MainActor
final class HomeShortcutRecorder: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var title = HomeKeyboardShortcut.current?.title
    @Published private(set) var notice: String?
    private var monitor: Any?
    private weak var shortcutMonitor: GlobalPushToTalkShortcutMonitor?
    func start(monitor shortcutMonitor: GlobalPushToTalkShortcutMonitor) {
        stop()
        guard let panel = NSApp.currentEvent?.window as? CursyEditingPanel else { return }
        panel.beginEditing()
        self.shortcutMonitor = shortcutMonitor
        shortcutMonitor.isSuspended = true
        recording = true
        notice = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { self.stop(); return nil }
            guard let shortcut = HomeKeyboardShortcut.make(keyCode: event.keyCode, flags: event.modifierFlags,
                characters: event.charactersIgnoringModifiers ?? "") else {
                self.notice = "Combinación reservada o incompleta · Reserved or incomplete combination"
                return nil
            }
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: HomeKeyboardShortcut.preferenceKey)
                self.title = shortcut.title
            }
            self.stop()
            return nil
        }
    }
    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        shortcutMonitor?.isSuspended = false
        shortcutMonitor = nil
        recording = false
    }
    func reset() {
        stop()
        UserDefaults.standard.removeObject(forKey: HomeKeyboardShortcut.preferenceKey)
        title = nil
    }
}
