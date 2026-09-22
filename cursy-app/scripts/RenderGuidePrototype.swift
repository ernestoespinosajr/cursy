import AppKit
import SwiftUI
@testable import Cursy

/// Renders the production guide view with injected synthetic data. Does not start
/// the manager, record audio, capture a display, load stored guides, or call a model.
@main
struct RenderGuidePrototype {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        guard CommandLine.arguments.count == 2 else { throw URLError(.badURL) }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let manager = CompanionManager()
        let plan = WalkthroughPlan(goal: "Organizar los archivos de la propuesta", steps: [
            .init(instruction: "Abre la carpeta que contiene la propuesta.", successCriterion: "La carpeta está abierta",
                  requiresExplicitConfirmation: false, indications: []),
            .init(instruction: "Arrastra el documento hacia la carpeta Aprobados.", successCriterion: "Documento dentro de Aprobados",
                  requiresExplicitConfirmation: false, indications: []),
            .init(instruction: "Revisa que el documento esté en su destino.", successCriterion: "Documento visible",
                  requiresExplicitConfirmation: false, indications: [])
        ])
        let coordinator = WalkthroughCoordinator(dependencies: .init(plan: { _ in plan },
            capture: { throw CancellationError() }, locate: { _, _, _ in [] },
            verify: { _, _, _ in throw CancellationError() }, allowed: { _ in false }, publish: { _ in }))
        coordinator.prepare(request: "Fixture", conversationID: manager.chatLibrary.selectedID)
        while coordinator.isPreparing { await Task.yield() }
        for phase in ["draft", "active", "completed"] {
            if phase == "active" { coordinator.start(); coordinator.confirmCurrentStep() }
            if phase == "completed" { coordinator.confirmCurrentStep(); coordinator.confirmCurrentStep() }
            let content = WalkthroughPanel(manager: manager, coordinator: coordinator)
                .frame(width: 420, height: 320, alignment: .top)
                .foregroundStyle(.white).background(Color(white: 0.09))
                .environment(\.colorScheme, .dark)
            let hosting = NSHostingView(rootView: content)
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 420, height: 320),
                styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { throw URLError(.cannotDecodeContentData) }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw URLError(.cannotDecodeContentData) }
            let destination = directory.appendingPathComponent("guide-\(phase).png")
            try data.write(to: destination)
            print(destination.path)
            window.close()
        }
        coordinator.cancel()
    }
}
