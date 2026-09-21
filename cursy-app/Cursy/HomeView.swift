import AppKit
import Combine
import SwiftUI

@MainActor
final class HomePresentationModel: ObservableObject {
    @Published var presentation: HomePresentation = .hidden
    @Published var reveal: CGFloat = 0
    @Published var notchWidth: CGFloat = 0
    @Published var notchHeight: CGFloat = 0
}

struct HomeView: View {
    @ObservedObject var companionManager: CompanionManager
    @ObservedObject var model: HomePresentationModel
    let onPresent: (HomePresentation) -> Void

    var body: some View {
        HomeContentView(presentation: model.presentation,
            activity: HomeActivity.resolve(session: companionManager.conversationSession,
                voiceState: companionManager.voiceState,
                permissionsReady: companionManager.allPermissionsGranted),
            exchanges: HomeExchange.visible(in: companionManager.conversationSession),
            isSpanish: companionManager.preferredLanguage == .spanish,
            screenSharingEnabled: companionManager.isVisualContextEnabled && companionManager.conversationSession.selectedText == nil,
            notice: companionManager.conversationNotice ?? companionManager.visualContextNotice,
            audioPowerLevel: companionManager.currentAudioPowerLevel,
            notchWidth: model.notchWidth,
            notchHeight: model.notchHeight,
            chats: companionManager.chatLibrary.records,
            selectedChatID: companionManager.chatLibrary.selectedID,
            canCreateChat: companionManager.chatLibrary.canCreate,
            onNewChat: companionManager.startNewConversation,
            onSelectChat: companionManager.selectConversation,
            settingsContent: { AnyView(HomeSettingsView(companionManager: companionManager, section: $0)) },
            composerContent: AnyView(HomeComposer(manager: companionManager)),
            selectionText: companionManager.conversationSession.selectedText?.text,
            needsSetup: !companionManager.allPermissionsGranted || !companionManager.hasCompletedOnboarding,
            onPresent: onPresent)
            .modifier(HomeReveal(progress: model.reveal, sourceWidth: model.notchWidth,
                                 sourceHeight: model.notchHeight))
    }
}

/// Kept independent of audio/capture so the same surface can be previewed offline.
struct HomeContentView: View {
    let presentation: HomePresentation
    let activity: HomeActivity
    let exchanges: [HomeExchange]
    let isSpanish: Bool
    let screenSharingEnabled: Bool
    let notice: String?
    var audioPowerLevel: CGFloat = 0
    var notchWidth: CGFloat = 0
    var notchHeight: CGFloat = 0
    var chats: [HomeChatRecord] = []
    var selectedChatID: UUID? = nil
    var canCreateChat = true
    var onNewChat: () -> Void = {}
    var onSelectChat: (UUID) -> Void = { _ in }
    var settingsContent: (HomeSidebarSection) -> AnyView = { _ in AnyView(EmptyView()) }
    var composerContent: AnyView = AnyView(EmptyView())
    var selectionText: String? = nil
    var needsSetup = false
    let onPresent: (HomePresentation) -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State var sidebarSection: HomeSidebarSection = .chats
    @State private var sidebarVisible = true

    private var isCompact: Bool { presentation == .compact }
    private var voiceFeedback: HomeVoiceFeedback {
        HomeVoiceFeedback(activity: activity, audioPowerLevel: audioPowerLevel)
    }

    var body: some View {
        Group {
            if isCompact { compactIsland } else { expandedSurface }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: isSpanish ? "es" : "en"))
        .onAppear {
            if needsSetup { sidebarSection = .privacy }
        }
        .onChange(of: needsSetup) { _, required in
            if required { sidebarSection = .privacy; sidebarVisible = true }
        }
    }

    private var compactIsland: some View {
        HStack(spacing: 0) {
            Button { onPresent(.expanded) } label: {
                VStack(spacing: 2) {
                    Text("Cursy").font(.system(size: 12, weight: .semibold))
                    Text(activity.title(isSpanish: isSpanish))
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1).minimumScaleFactor(0.85)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.buttonStyle(HomeControlStyle())
            .help(localized("Abrir conversación", "Open conversation"))
            if notchWidth > 0 {
                Color.clear.frame(width: notchWidth + 16).allowsHitTesting(false).accessibilityHidden(true)
            }
            Button { onPresent(.expanded) } label: {
                HStack(spacing: 12) {
                    if voiceFeedback.isListening { HomeVoiceWaveform(feedback: voiceFeedback) }
                    else { Image(systemName: activity == .processing || activity == .connecting ? "ellipsis" : "waveform") }
                    Image(systemName: "chevron.down").font(.system(size: 10))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.buttonStyle(HomeControlStyle())
            .accessibilityLabel(localized("Abrir conversación", "Open conversation"))
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if notchWidth > 0 { HomeIslandShape().fill(.black) }
            else { RoundedRectangle(cornerRadius: 18).fill(.black) }
        }
        .clipShape(notchWidth > 0 ? AnyShape(HomeIslandShape()) : AnyShape(RoundedRectangle(cornerRadius: 18)))
    }

    private var expandedSurface: some View {
        VStack(spacing: 0) {
            header
            if !isCompact {
                Divider()
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        if sidebarVisible {
                            sidebar.frame(width: geometry.size.width < 580 ? 136 : 186)
                                .frame(maxHeight: .infinity, alignment: .top)
                            Divider()
                        }
                        if sidebarSection == .chats { conversation }
                        else { settingsContent(sidebarSection).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .padding(.top, notchWidth > 0 ? notchHeight + HomeSurfaceShape.neckHeight : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            HomeGlassSurface(notchWidth: notchWidth, notchHeight: notchHeight)
        }
        .clipShape(HomeSurfaceShape(notchWidth: notchWidth, notchHeight: notchHeight))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: isSpanish ? "es" : "en"))
    }

    private var header: some View {
        HStack(spacing: 10) {
            if !isCompact {
                control("xmark", localized("Cerrar Home", "Close Home")) { onPresent(.hidden) }
                control("sidebar.left", localized("Barra lateral", "Sidebar")) { sidebarVisible.toggle() }
            }
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if !isCompact {
                    HStack(spacing: 8) {
                        Text("Cursy").font(.headline)
                        Text(localized("Temporal", "Temporary")).font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .help(localized("Esta conversación se conserva solo durante la sesión actual.",
                                            "This conversation lasts for the current session only."))
                    }
                }
                HStack(spacing: 9) {
                    Text(activity.title(isSpanish: isSpanish))
                        .font(isCompact ? .subheadline.weight(.medium) : .caption)
                        .foregroundStyle(.white.opacity(isCompact ? 1 : 0.85))
                        .lineLimit(1)
                        .accessibilityLabel(activity.title(isSpanish: isSpanish))
                    if voiceFeedback.isListening {
                        HomeVoiceWaveform(feedback: voiceFeedback)
                    }
                }
            }
            Spacer(minLength: 4)
            if isCompact {
                control("chevron.down", localized("Expandir Home", "Expand Home")) { onPresent(.expanded) }
                control("xmark", localized("Cerrar Home", "Close Home")) { onPresent(.hidden) }
            } else {
                HomeShortcutHint(spanish: isSpanish)
                Image(systemName: screenSharingEnabled ? "rectangle.inset.filled" : "rectangle.slash")
                    .foregroundStyle(screenSharingEnabled ? Color.mint : Color.white.opacity(0.8))
                    .help(localized(screenSharingEnabled ? "Pantalla habilitada" : "Pantalla desactivada",
                                    screenSharingEnabled ? "Screen sharing enabled" : "Screen sharing off"))
                    .accessibilityLabel(localized(screenSharingEnabled ? "Pantalla habilitada" : "Pantalla desactivada",
                                                  screenSharingEnabled ? "Screen sharing enabled" : "Screen sharing off"))
                control("gearshape", localized("Ajustes", "Settings")) {
                    sidebarVisible = true
                    sidebarSection = HomeSidebarSection.settingsLanding(needsSetup: needsSetup)
                }
                control(presentation == .detached ? "pin" : "pip.exit",
                        presentation == .detached ? localized("Anclar arriba", "Attach at top")
                            : localized("Separar ventana", "Detach window")) {
                    onPresent(presentation == .detached ? .expanded : .detached)
                }
                control("chevron.up", localized("Compactar Home", "Collapse Home")) { onPresent(.compact) }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: isCompact ? 58 : 68)
        .background {
            if voiceFeedback.isListening && !reduceTransparency {
                HomeVoiceGlow(feedback: voiceFeedback)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sidebarSection == .chats {
                HStack {
                    Text("Chats").font(.headline)
                    Spacer()
                    control("plus", localized("Nueva conversación", "New conversation"), action: onNewChat)
                        .disabled(!canCreateChat)
                }
                ScrollView {
                    VStack(spacing: 6) {
                        if chats.isEmpty {
                            Label(localized("Conversación actual", "Current conversation"), systemImage: "bubble.left")
                                .font(.caption).padding(8)
                        }
                        ForEach(chats.reversed()) { chat in
                            Button { onSelectChat(chat.id) } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(chat.title(spanish: isSpanish)).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                    Text(localized("Temporal", "Temporary")).font(.caption2).foregroundStyle(.white.opacity(0.75))
                                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(chat.id == selectedChatID ? .white.opacity(0.12) : .clear,
                                                in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(HomeControlStyle())
                                .accessibilityAddTraits(chat.id == selectedChatID ? .isSelected : [])
                        }
                    }
                }
                if !canCreateChat { Text(localized("Límite: 20 chats temporales", "Limit: 20 temporary chats")).font(.caption2) }
                Text(localized("Solo durante esta sesión", "Only during this session"))
                    .font(.caption2).foregroundStyle(.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
                Button { sidebarSection = HomeSidebarSection.settingsLanding(needsSetup: needsSetup) } label: {
                    Label(localized("Ajustes", "Settings"), systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }.buttonStyle(HomeControlStyle())
            } else {
                Button { sidebarSection = .chats } label: {
                    Label(localized("Volver a chats", "Back to chats"), systemImage: "chevron.left")
                        .padding(.vertical, 8)
                }.buttonStyle(HomeControlStyle())
                Text(localized("Ajustes", "Settings")).font(.headline)
                ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                ForEach(HomeSidebarSection.allCases.filter { $0 != .chats }) { section in
                    Button { sidebarSection = section } label: {
                        Label(section.title(spanish: isSpanish), systemImage: section.symbol)
                            .font(.system(size: 12, weight: .medium)).padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(sidebarSection == section ? .white.opacity(0.12) : .clear,
                                        in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(HomeControlStyle())
                }
                }
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            conversationHistory
            composerContent
        }
    }

    private var conversationHistory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let selectionText {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(localized("Solo texto seleccionado", "Selected text only"), systemImage: "text.quote").font(.caption)
                        Text(selectionText).font(.callout).lineLimit(3).textSelection(.enabled)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                }
                if exchanges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localized("Tu conversación,\nsin salir de lo que haces.",
                                       "Your conversation,\nright where you work."))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                        Text(localized("Escribe abajo o usa el micrófono. La conversación aparecerá aquí.",
                                       "Type below or use the microphone. Your conversation will appear here."))
                            .font(.body).foregroundStyle(.white.opacity(0.85))
                        Label(localized("El cursor sigue guiándote en pantalla.",
                                        "The cursor still guides you on screen."), systemImage: "cursorarrow")
                            .font(.callout).foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.vertical, 25)
                    .padding(.horizontal, 16)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                } else {
                    ForEach(exchanges) { exchange in
                        if !exchange.request.isEmpty {
                            message(exchange.request, speaker: localized("Tú", "You"), isUser: true)
                        }
                        if !exchange.response.isEmpty {
                            message(exchange.response, speaker: "Cursy", isUser: false)
                        }
                    }
                }
                if activity == .failed || activity == .setupRequired {
                    Label(activity == .setupRequired
                          ? localized("Abre Ajustes para revisar los permisos.", "Open Settings to review permissions.")
                          : localized("Puedes volver a intentarlo con el atajo de voz.", "You can try again with the voice shortcut."),
                          systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.white.opacity(0.85))
                        .padding(10)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                }
                if let notice, !notice.isEmpty {
                    Text(notice).font(.caption).foregroundStyle(.white.opacity(0.85))
                        .padding(10)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    private func message(_ text: String, speaker: String, isUser: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(speaker).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.55))
                .overlay {
                    if isUser { RoundedRectangle(cornerRadius: 12).fill(.mint.opacity(0.08)) }
                }
        }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 28, height: 28).contentShape(Rectangle())
        }
        .buttonStyle(HomeControlStyle())
        .help(label).accessibilityLabel(label)
    }

    private func localized(_ spanish: String, _ english: String) -> String { isSpanish ? spanish : english }
}

struct HomeControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HomeControlBody(configuration: configuration)
    }

    private struct HomeControlBody: View {
        let configuration: Configuration
        @State private var isHovering = false
        var body: some View {
            configuration.label
                .foregroundStyle(.white.opacity(0.8))
                .background(Color.primary.opacity(configuration.isPressed ? 0.14 : isHovering ? 0.07 : 0),
                            in: RoundedRectangle(cornerRadius: 7))
                .pointerCursor()
                .onHover { isHovering = $0 }
        }
    }
}
