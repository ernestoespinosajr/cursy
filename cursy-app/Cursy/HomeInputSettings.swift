import AppKit
import SwiftUI

struct HomeMicrophoneSettings: View {
    @ObservedObject var microphone: HomeMicrophone
    @ObservedObject var manager: CompanionManager
    private var spanish: Bool { manager.preferredLanguage == .spanish }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker(spanish ? "Entrada" : "Input", selection: Binding(get: { microphone.selectedUID }, set: microphone.select)) {
                Text(spanish ? "Predeterminado del sistema" : "System default").tag("")
                ForEach(microphone.devices) { Text($0.name).tag($0.id) }
                if microphone.missingSelection { Text(spanish ? "Desconectado" : "Disconnected").tag(microphone.selectedUID) }
            }.disabled(manager.voiceState != .idle || microphone.ownsInput).pointerCursor()
            if microphone.missingSelection {
                Text(spanish ? "El micrófono guardado no está disponible. Selecciona otro o el predeterminado del sistema." : "Your saved microphone is unavailable. Select another or the system default.")
                    .font(.caption)
            }
            ProgressView(value: microphone.level).accessibilityLabel(spanish ? "Nivel del micrófono" : "Microphone level")
            Button {
                if microphone.ownsInput { microphone.stop() }
                else { microphone.start(canStart: { manager.voiceState == .idle }) }
            } label: {
                Label(microphone.isStopping ? (spanish ? "Cerrando prueba…" : "Closing test…") : microphone.isStarting ? (spanish ? "Cancelar conexión" : "Cancel connection") : microphone.isTesting ? (spanish ? "Detener prueba" : "Stop test") : (spanish ? "Probar micrófono" : "Test microphone"),
                    systemImage: microphone.isTesting ? "stop.circle" : "mic")
            }.disabled(manager.voiceState != .idle || microphone.missingSelection || microphone.isStopping).pointerCursor()
            Text(spanish ? "Prueba local de 15 segundos. No se guarda ni se envía audio; solo se muestra el nivel de entrada." : "15-second local test. No audio is stored or sent; only the input level is shown.")
                .font(.caption).foregroundStyle(.secondary)
            if let notice = microphone.notice { Text(notice).font(.caption) }
        }.onAppear { microphone.refresh() }.onDisappear { microphone.stop() }
    }
}

struct HomeShortcutSettings: View {
    @ObservedObject var manager: CompanionManager
    var body: some View {
        HomeShortcutControls(manager: manager, recorder: manager.homeShortcutRecorder)
    }
}

private struct HomeShortcutControls: View {
    @ObservedObject var manager: CompanionManager
    @ObservedObject var recorder: HomeShortcutRecorder
    @AppStorage("pushToTalkShortcut") private var selected = "controlOption"
    private var spanish: Bool { manager.preferredLanguage == .spanish }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button {
                if recorder.recording { recorder.stop() }
                else { recorder.start(monitor: manager.globalPushToTalkShortcutMonitor) }
            } label: {
                Label(recorder.recording ? (spanish ? "Pulsa una combinación… Esc cancela" : "Press a combination… Esc cancels") :
                    (recorder.title ?? (spanish ? "Grabar otro atajo" : "Record another shortcut")), systemImage: "keyboard")
            }.disabled(manager.voiceState != .idle).pointerCursor()
            if let notice = recorder.notice { Text(notice).font(.caption) }
            Picker(spanish ? "Mantener para hablar" : "Hold to talk", selection: $selected) {
                ForEach(BuddyPushToTalkShortcut.ShortcutOption.allCases, id: \.rawValue) { option in
                    Text(option.displayText).tag(option.rawValue)
                }
            }.disabled(manager.voiceState != .idle || recorder.recording).pointerCursor()
                .onChange(of: selected) { recorder.reset() }
            Text(spanish ? "Elige una combinación que no uses en otras apps. macOS no permite detectar todos los conflictos globales." : "Choose a combination you don't use in other apps. macOS cannot detect every global conflict.")
                .font(.caption).foregroundStyle(.secondary)
            Button(spanish ? "Restablecer Control + Opción" : "Reset Control + Option") { recorder.reset(); selected = "controlOption" }
                .disabled(manager.voiceState != .idle).pointerCursor()
        }.onDisappear { recorder.stop() }
    }
}

struct HomeShortcutHint: View {
    let spanish: Bool
    @AppStorage("pushToTalkShortcut") private var selected = "controlOption"
    @AppStorage(HomeKeyboardShortcut.preferenceKey) private var customData = Data()
    var body: some View {
        let option = BuddyPushToTalkShortcut.ShortcutOption(rawValue: selected) ?? .controlOption
        HStack(spacing: 4) {
            Image(systemName: "mic")
            if !customData.isEmpty, let custom = HomeKeyboardShortcut.current {
                Text(custom.title).font(.caption2)
            } else {
            ForEach(option.keyCapsuleLabels, id: \.self) { key in
                Image(systemName: key == "ctrl" ? "control" : key == "fn" ? "fn" : key)
            }
            }
        }.font(.caption)
            .accessibilityLabel((spanish ? "Mantén para hablar: " : "Hold to talk: ") + (HomeKeyboardShortcut.current?.title ?? option.displayText))
            .help(HomeKeyboardShortcut.current?.title ?? option.displayText)
    }
}
