import SwiftUI

enum HomeSidebarSection: String, CaseIterable, Identifiable {
    case chats, general, cursor, privacy
    var id: Self { self }
    var symbol: String {
        switch self {
        case .chats: return "bubble.left.and.bubble.right"
        case .general: return "gearshape"
        case .cursor: return "cursorarrow.motionlines"
        case .privacy: return "hand.raised"
        }
    }
    func title(spanish: Bool) -> String {
        switch self {
        case .chats: return "Chats"
        case .general: return "General"
        case .cursor: return "Cursor"
        case .privacy: return spanish ? "Privacidad" : "Privacy"
        }
    }
}

struct HomeSettingsView: View {
    @ObservedObject var companionManager: CompanionManager
    let section: HomeSidebarSection
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
                    Picker(spanish ? "Indicación visual" : "Visual indication", selection: $companionManager.preferredAnnotationStyle) {
                        ForEach(VisualAnnotationStyle.allCases) { style in Text(style.title(spanish: spanish)).tag(style) }
                    }.pointerCursor()
                    Picker(spanish ? "Modelo de respaldo" : "Fallback model", selection: Binding(
                        get: { companionManager.selectedModel }, set: { companionManager.setSelectedModel($0) })) {
                        Text("GPT-4.1").tag("gpt-4.1")
                        Text("GPT-4.1 mini").tag("gpt-4.1-mini")
                    }.pointerCursor()
                    Label(spanish ? "Mantén Control + Opción para hablar" : "Hold Control + Option to talk", systemImage: "mic")
                    Text(spanish ? "Los cambios se aplican a las próximas interacciones. No cambian el modelo de voz ni el de localización." :
                         "Changes apply to future interactions. Voice and localization models stay unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                case .privacy:
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
                    Label(spanish ? "Chats temporales en este Mac" : "Temporary chats on this Mac", systemImage: "clock")
                    Text(spanish ? "Se conservan solo mientras Cursy está abierto: hasta 20 chats y contexto acotado de 10 intercambios por chat. No se guardan imágenes ni audio." :
                         "Kept only while Cursy is open: up to 20 chats and bounded context of 10 exchanges per chat. Images and audio are never stored.")
                        .font(.caption).foregroundStyle(.secondary)
                case .chats: EmptyView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        CursyCursorTint.resolve(storedTint) == tint ? tint.color : .white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(HomeControlStyle()).pointerCursor()
                .accessibilityLabel(tint.title(spanish: spanish))
                .accessibilityAddTraits(CursyCursorTint.resolve(storedTint) == tint ? .isSelected : [])
            }
        }
    }
}
