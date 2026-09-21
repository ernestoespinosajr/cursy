import AppKit
import SwiftUI
@testable import Cursy

/// Offline review of the production view with synthetic messages; no manager,
/// audio, capture, credentials, network, or app activation.
@main
struct RenderHomePrototype {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            throw NSError(domain: "HomePreview", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Pass an existing output directory"])
        }
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let exchange = HomeExchange(id: ConversationTurnID(), request: "¿Qué significa esta parte del diagrama?",
            response: "Representa la entrada de datos. La flecha indica hacia dónde pasan al siguiente componente.")
        var library = HomeChatLibrary()
        for title in ["Revisar una propuesta", "Entender un diagrama"] {
            var session = ConversationSession()
            let turn = session.beginTurn()
            session.setTranscript(title, for: turn)
            library.updateCurrent(session)
            if title == "Revisar una propuesta" { library.create() }
        }
        for dark in [false, true] {
          for section in [HomeSidebarSection.chats, .cursor] {
            let content = VStack(spacing: 20) {
                // Synthetic camera housing for checking the flush black join.
                ZStack(alignment: .top) {
                HomeContentView(presentation: .compact, activity: .listening, exchanges: [],
                    isSpanish: true, screenSharingEnabled: true, notice: nil,
                    audioPowerLevel: 0.75, notchWidth: 208, notchHeight: 38,
                    onPresent: { _ in })
                    .frame(width: 460, height: 52)
                    RoundedRectangle(cornerRadius: 7).fill(.black).frame(width: 208, height: 38)
                }
                HomeContentView(presentation: .compact, activity: .listening, exchanges: [],
                    isSpanish: true, screenSharingEnabled: true, notice: nil,
                    audioPowerLevel: 0.75,
                    onPresent: { _ in })
                    .frame(width: 320, height: 58)
                ZStack(alignment: .top) {
                HomeContentView(presentation: .expanded, activity: .ready, exchanges: [exchange],
                    isSpanish: true, screenSharingEnabled: true, notice: nil,
                    notchWidth: 208, notchHeight: 38,
                    chats: library.records, selectedChatID: library.selectedID,
                    settingsContent: { _ in AnyView(VStack(alignment: .leading, spacing: 24) {
                        Text("Cursor").font(.title2.bold())
                        Text("Vidrio con tu color y una sombra a juego.")
                        CursyTintPicker(spanish: true)
                        Spacer()
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)) },
                    onPresent: { _ in }, sidebarSection: section)
                    .frame(width: 840, height: 592)
                    RoundedRectangle(cornerRadius: 7).fill(.black).frame(width: 208, height: 38)
                }
            }
            .padding(30)
            .background {
                // Synthetic colored desktop, so translucency isn't mistaken for
                // a flat black/gray fill. Native backdrop optics still need live QA.
                LinearGradient(colors: dark
                    ? [Color(red: 0.12, green: 0.07, blue: 0.04), .indigo.opacity(0.6), .black]
                    : [Color(red: 0.85, green: 0.65, blue: 0.46), .white, .blue.opacity(0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack(spacing: 75) {
                    ForEach(0..<5) { _ in Rectangle().fill(.white.opacity(0.12)).frame(width: 55) }
                }
            }
            .environment(\.colorScheme, dark ? .dark : .light)
            // ImageRenderer omits AppKit-backed ScrollView content. Render the
            // hosting hierarchy in an unordered window instead, without capture.
            let hosting = NSHostingView(rootView: content)
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 822),
                styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
                throw NSError(domain: "HomePreview", code: 2)
            }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "HomePreview", code: 2)
            }
            let destination = output.appendingPathComponent("home-\(section.rawValue)-\(dark ? "dark" : "light").png")
            try data.write(to: destination)
            print(destination.path)
            window.close()
          }
        }
    }
}
