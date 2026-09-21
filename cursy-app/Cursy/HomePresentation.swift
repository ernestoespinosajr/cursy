import Foundation
import CoreGraphics

enum HomePresentation: Equatable {
    case hidden, compact, expanded, detached
}

enum HomeActivity: Equatable {
    case ready, setupRequired, connecting, listening, processing, responding, failed, cancelled

    static func resolve(session: ConversationSession, voiceState: CompanionVoiceState,
                        permissionsReady: Bool) -> Self {
        guard permissionsReady else { return .setupRequired }
        if session.currentTurn?.state == .failed { return .failed }
        if session.currentTurn?.state == .cancelled { return .cancelled }
        switch voiceState {
        case .idle: return .ready
        case .connecting: return .connecting
        case .listening: return .listening
        case .processing: return .processing
        case .responding: return .responding
        }
    }

    func title(isSpanish: Bool) -> String {
        switch self {
        case .ready: return isSpanish ? "Listo para ayudarte" : "Ready to help"
        case .setupRequired: return isSpanish ? "Revisa los permisos" : "Check permissions"
        case .connecting: return isSpanish ? "Conectando" : "Connecting"
        case .listening: return isSpanish ? "Te escucho" : "Listening"
        case .processing: return isSpanish ? "Pensando" : "Thinking"
        case .responding: return isSpanish ? "Respondiendo" : "Responding"
        case .failed: return isSpanish ? "No se pudo completar" : "Could not complete"
        case .cancelled: return isSpanish ? "Interrumpido" : "Interrupted"
        }
    }
}

struct HomeExchange: Identifiable {
    let id: ConversationTurnID
    let request: String
    let response: String

    /// Projection only: no second conversation store or screenshot history.
    static func visible(in session: ConversationSession) -> [Self] {
        var exchanges = session.exchanges.map {
            Self(id: $0.turnID, request: $0.userTranscript, response: $0.assistantResponse)
        }
        if let current = session.currentTurn,
           !exchanges.contains(where: { $0.id == current.id }),
           !current.transcript.isEmpty || !current.response.isEmpty {
            exchanges.append(Self(id: current.id, request: current.transcript, response: current.response))
        }
        return exchanges
    }
}

enum HomePanelLayout {
    /// The gap between the two system-provided menu areas is the camera housing.
    /// Rectangles use global AppKit coordinates, including negative display origins.
    static func notch(screenFrame: CGRect, safeTopInset: CGFloat,
                      leftArea: CGRect?, rightArea: CGRect?) -> CGRect? {
        guard safeTopInset > 0, safeTopInset < screenFrame.height,
              let leftArea, let rightArea,
              !leftArea.isEmpty, !rightArea.isEmpty,
              leftArea.maxX < rightArea.minX,
              leftArea.maxX > screenFrame.minX, rightArea.minX < screenFrame.maxX else { return nil }
        return CGRect(x: leftArea.maxX, y: screenFrame.maxY - safeTopInset,
                      width: rightArea.minX - leftArea.maxX, height: safeTopInset)
    }

    static func frame(presentation: HomePresentation, screenFrame: CGRect,
                      visibleFrame: CGRect, safeTopInset: CGFloat, notch: CGRect? = nil) -> CGRect {
        let margin: CGFloat = 12
        let isAttached = presentation != .detached && notch != nil
        let safeTop = isAttached ? screenFrame.maxY
            : min(visibleFrame.maxY, screenFrame.maxY - max(0, safeTopInset))
        let topMargin: CGFloat = isAttached ? 0 : margin
        let availableWidth = max(1, visibleFrame.width - margin * 2)
        let availableHeight = max(1, safeTop - visibleFrame.minY - margin - topMargin)
        let isCompact = presentation == .compact
        let width = min(isCompact ? (isAttached ? notch!.width + 252 : 320) : 840, availableWidth)
        // Attached compact content lives beside the camera, not below it.
        let compactHeight = isAttached ? max(52, notch!.height + 14) : 58
        let height = min(isCompact ? compactHeight
            : 540 + (isAttached ? notch!.height + HomeSurfaceShape.neckHeight : 0), availableHeight)
        let originY = presentation == .detached
            ? visibleFrame.minY + margin + (availableHeight - height) / 2
            : safeTop - topMargin - height
        let centerX = isAttached ? notch!.midX : visibleFrame.midX
        let originX = min(max(centerX - width / 2, visibleFrame.minX + margin),
                          visibleFrame.maxX - margin - width)
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    static func clamped(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        return CGRect(x: min(max(frame.minX, visibleFrame.minX), visibleFrame.maxX - width),
                      y: min(max(frame.minY, visibleFrame.minY), visibleFrame.maxY - height),
                      width: width, height: height)
    }
}
