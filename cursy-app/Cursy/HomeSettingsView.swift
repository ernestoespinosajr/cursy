import AppKit
import AVFoundation
import SwiftUI

enum HomeSidebarSection: String, CaseIterable, Identifiable {
    case chats, general, voice, microphone, shortcuts, cursor, privacy, help
    var id: Self { self }
    var symbol: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right"
        case .general: return "gearshape"
        case .voice: return "waveform"
        case .microphone: return "mic"
        case .shortcuts: return "command"
        case .cursor: return "cursorarrow.motionlines"
        case .privacy: return "hand.raised"
        case .help: return "questionmark.circle"
        }
    }
    func title(spanish: Bool) -> String {
        switch self {
        case .chats: return "Chats"
        case .general: return "General"
        case .voice: return spanish ? "Voz" : "Voice"
        case .microphone: return spanish ? "Micrófono" : "Microphone"
        case .shortcuts: return spanish ? "Atajos" : "Shortcuts"
        case .cursor: return "Cursor"
        case .privacy: return spanish ? "Privacidad" : "Privacy"
        case .help: return spanish ? "Ayuda" : "Help"
        }
    }

    static func settingsLanding(needsSetup: Bool) -> Self { needsSetup ? .privacy : .general }
}

struct HomeSettingsView: View {
    @ObservedObject var companionManager: CompanionManager
    let section: HomeSidebarSection
    @AppStorage("showListeningHint") private var showListeningHint = true
    private var spanish: Bool { companionManager.preferredLanguage == .spanish }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(section.title(spanish: spanish)).font(.title2.bold())
                switch section {
                case .cursor:
                    Text(spanish ? "Vidrio con tu color y una sombra a juego." : "Tinted glass with a matching shadow.")
                        .foregroundStyle(.secondary)
                    CursyTintPicker(spanish: spanish)
                    Toggle(spanish ? "Mostrar cursor" : "Show cursor", isOn: Binding(
                        get: { companionManager.isCursyCursorEnabled },
                        set: { companionManager.setCursyCursorEnabled($0) }))
                        .pointerCursor()
                case .general:
                    Picker(spanish ? "Idioma" : "Language", selection: Binding(
                        get: { companionManager.preferredLanguage },
                        set: { companionManager.setPreferredLanguage($0) })) {
                        ForEach(CursyLanguage.allCases) { language in Text(language.displayName).tag(language) }
                    }.pointerCursor()
                    Picker(spanish ? "Modelo de respaldo" : "Fallback model", selection: Binding(
                        get: { companionManager.selectedModel }, set: { companionManager.setSelectedModel($0) })) {
                        Text("GPT-4.1").tag("gpt-4.1")
                        Text("GPT-4.1 mini").tag("gpt-4.1-mini")
                    }.pointerCursor()
                    HomeShortcutHint(spanish: spanish)
                    Text(spanish ? "Los cambios se aplican a las próximas interacciones. No cambian el modelo de voz ni el de localización." :
                         "Changes apply to future interactions. Voice and localization models stay unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                case .voice:
                    Toggle(spanish ? "Leer respuestas de texto en voz alta" : "Read text replies aloud", isOn: $companionManager.readTextRepliesAloud).pointerCursor()
                    Label("Marin · OpenAI Realtime", systemImage: "waveform")
                    Text(spanish ? "La voz y su velocidad las determina el servicio actual. El micrófono solo se activa al pedir hablar." : "Voice and speed are determined by the current service. The microphone starts only when you ask to talk.")
                        .font(.caption).foregroundStyle(.secondary)
                case .microphone:
                    HomeMicrophoneSettings(microphone: companionManager.homeMicrophone, manager: companionManager)
                case .shortcuts:
                    HomeShortcutSettings(manager: companionManager)
                case .privacy:
                    Toggle(spanish ? "Mostrar aviso «Señala mientras hablas»" : "Show ‘Point while speaking’ hint", isOn: $showListeningHint).pointerCursor()
                    permissions
                    Divider()
                    Toggle(spanish ? "Compartir pantalla" : "Share screen", isOn: $companionManager.isVisualContextEnabled).pointerCursor()
                    Text(spanish ? "Al soltar el atajo, Cursy puede enviar a OpenAI la pantalla del puntero. Abrir Home no captura ni envía tu pantalla." :
                         "On shortcut release, Cursy may send OpenAI the pointer’s screen. Opening Home never captures or sends your screen.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle(spanish ? "Actualizar indicación" : "Refresh indication", isOn: $companionManager.isVisualRefreshEnabled).pointerCursor()
                    Toggle(spanish ? "Contexto espacial" : "Spatial context", isOn: $companionManager.isSpatialContextEnabled)
                        .disabled(!companionManager.isVisualContextEnabled).pointerCursor()
                    Text(spanish ? "La huella se envía con la imagen al soltar; no se guarda. La indicación puede comprobar la pantalla dos veces durante un máximo de 30 segundos." :
                         "The pointer trail is sent with the image on release, never saved. Guidance can recheck the screen twice over at most 30 seconds.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let notice = companionManager.visualContextNotice {
                        Text(notice).font(.caption).foregroundStyle(.secondary)
                    }
                    Label(spanish ? "Chats temporales en este Mac" : "Temporary chats on this Mac", systemImage: "clock")
                    Text(spanish ? "Se conservan solo mientras Cursy está abierto: hasta 20 chats y contexto acotado de 10 intercambios por chat. No se guardan imágenes ni audio." :
                         "Kept only while Cursy is open: up to 20 chats and bounded context of 10 exchanges per chat. Images and audio are never stored.")
                        .font(.caption).foregroundStyle(.secondary)
                case .help:
                    HomeShortcutHint(spanish: spanish)
                    introductionButton
                    Button {
                        if let url = URL(string: "mailto:hello@hellocursy.com") { NSWorkspace.shared.open(url) }
                    } label: {
                        Label(spanish ? "Enviar comentarios" : "Send feedback", systemImage: "bubble.left")
                    }.pointerCursor()
                    Text(spanish ? "Ideas, errores o sugerencias. Se abrirá tu aplicación de correo." :
                         "Ideas, bugs or suggestions. Opens your email application.")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Button { NSApp.terminate(nil) } label: {
                        Label(spanish ? "Salir de Cursy" : "Quit Cursy", systemImage: "power")
                    }.pointerCursor()
                case .chats: EmptyView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(spanish ? "Permisos del sistema" : "System permissions").font(.headline)
            Text(spanish ? "Autoriza estas funciones para hablar con Cursy y recibir ayuda. Permitir acceso no activa Compartir pantalla." :
                 "Allow these features to talk with Cursy and get help. Granting access does not turn on Share screen.")
                .font(.caption).foregroundStyle(.secondary)
            permissionRow(symbol: "mic", title: spanish ? "Micrófono" : "Microphone",
                granted: companionManager.hasMicrophonePermission, action: requestMicrophonePermission)
            permissionRow(symbol: "hand.raised", title: spanish ? "Accesibilidad" : "Accessibility",
                granted: companionManager.hasAccessibilityPermission,
                action: { _ = WindowPositionManager.requestAccessibilityPermission() })
            if !companionManager.hasAccessibilityPermission {
                Button {
                    WindowPositionManager.revealAppInFinder()
                    WindowPositionManager.openAccessibilitySettings()
                } label: {
                    Label(spanish ? "Buscar app en Finder" : "Find app in Finder", systemImage: "folder")
                }.pointerCursor()
            }
            permissionRow(symbol: "rectangle.dashed.badge.record", title: spanish ? "Grabación de pantalla" : "Screen Recording",
                granted: companionManager.hasScreenRecordingPermission,
                action: { _ = WindowPositionManager.requestScreenRecordingPermission() })
            if companionManager.hasScreenRecordingPermission {
                permissionRow(symbol: "eye", title: spanish ? "Contenido de pantalla" : "Screen Content",
                    granted: companionManager.hasScreenContentPermission, action: companionManager.requestScreenContentPermission)
            }
            if !companionManager.hasCompletedOnboarding { introductionButton }
        }
    }

    private func permissionRow(symbol: String, title: String, granted: Bool,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: symbol)
            Spacer(minLength: 8)
            if granted {
                Label(spanish ? "Permitido" : "Allowed", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button(spanish ? "Permitir" : "Allow", action: action)
                    .buttonStyle(.borderedProminent).pointerCursor()
            }
        }
    }

    private var introductionButton: some View {
        Button {
            if companionManager.hasCompletedOnboarding { companionManager.replayOnboarding() }
            else { companionManager.triggerOnboarding() }
        } label: {
            Label(companionManager.hasCompletedOnboarding
                  ? (spanish ? "Repetir introducción" : "Replay introduction")
                  : (spanish ? "Comenzar" : "Get started"), systemImage: "play.circle")
        }
        .disabled(!companionManager.allPermissionsGranted)
        .pointerCursor()
    }

    private func requestMicrophonePermission() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct CursyTintPicker: View {
    let spanish: Bool
    @AppStorage(CursyCursorTint.preferenceKey) private var storedTint = CursyCursorTint.mint.rawValue

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 12)], spacing: 12) {
            ForEach(CursyCursorTint.allCases) { tint in
                Button { storedTint = tint.rawValue } label: {
                    VStack(spacing: 14) {
                        // A legible swatch, not a live overlay: native glass-only
                        // layers can disappear in cached/offscreen sidebar cells.
                        Image(systemName: "cursorarrow")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(LinearGradient(colors: [tint.color.opacity(0.65), tint.color],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 26, height: 26)
                            .shadow(color: tint.color.opacity(0.65), radius: 9, y: 2)
                            .frame(height: 40)
                        Text(tint.title(spanish: spanish)).font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .topTrailing) {
                        if CursyCursorTint.resolve(storedTint) == tint {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(tint.color).padding(8)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                        .white.opacity(CursyCursorTint.resolve(storedTint) == tint ? 0.55 : 0.12), lineWidth: 1))
                }
                .buttonStyle(HomeControlStyle()).pointerCursor()
                .accessibilityLabel(tint.title(spanish: spanish))
                .accessibilityAddTraits(CursyCursorTint.resolve(storedTint) == tint ? .isSelected : [])
            }
        }
    }
}
