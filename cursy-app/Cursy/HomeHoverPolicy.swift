import Foundation

enum HomeHoverIntent: Equatable {
    case none, open, hide
}

/// Pointer intent only. Opening Home never starts voice or screen sharing.
enum HomeHoverPolicy {
    static let openDelay: TimeInterval = 0.18
    static let hideDelay: TimeInterval = 0.8

    static func intent(presentation: HomePresentation, inTrigger: Bool, inPanel: Bool,
                       busy: Bool, dragging: Bool, suppressed: Bool,
                       voiceOver: Bool, closing: Bool = false) -> HomeHoverIntent {
        guard presentation != .detached else { return .none }
        if presentation == .hidden {
            return (inTrigger || (closing && inPanel)) && !dragging && !suppressed ? .open : .none
        }
        if presentation == .compact && inTrigger && !dragging && !suppressed { return .open }
        guard !inTrigger, !inPanel, !busy, !dragging, !voiceOver else { return .none }
        return .hide
    }
}
