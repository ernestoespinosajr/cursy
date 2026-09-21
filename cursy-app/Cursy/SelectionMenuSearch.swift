import Foundation
import CoreGraphics

/// Geometry/roles only; the AX adapter and fixtures use the same detector.
protocol SelectionMenuBackend {
    associatedtype Node: Equatable
    nonisolated var canContinue: Bool { get }
    nonisolated func hit(at point: CGPoint) -> Node?
    nonisolated func parent(of node: Node) -> Node?
    nonisolated func children(of node: Node, offset: Int, limit: Int) -> [Node]
    nonisolated func role(of node: Node) -> String?
    nonisolated func bounds(of node: Node) -> CGRect?
    nonisolated func isSecure(_ node: Node) -> Bool
}

nonisolated struct SelectionMenuSearch<Backend: SelectionMenuBackend> {
    let backend: Backend
    private var examined: [Backend.Node] = []

    init(backend: Backend) { self.backend = backend }

    /// Cover the horizontal strip instead of sampling only the edges/center.
    /// Spacing is smaller than the minimum admitted menu width/height.
    static func probePoints(selection: CGRect, window: CGRect) -> [CGPoint] {
        guard SelectionEvidence.validBounds(selection), SelectionEvidence.validBounds(window) else { return [] }
        let left = max(window.minX + 1, selection.minX - 160)
        let right = min(window.maxX - 1, selection.maxX + 160)
        guard right >= left, (right - left).isFinite, right - left <= 10_240 else { return [] }
        let steps = max(1, Int(ceil((right - left) / 40)))
        // Refuse pathological coordinate spans; normal displays fit this cap.
        guard steps <= 256 else { return [] }
        let center = min(max(selection.midX, left), right)
        let columns = [center] + (0...steps).map { left + (right - left) * CGFloat($0) / CGFloat(steps) }
        return [24.0, 8, 40, 56, 72, 88, 104, -8, -24].flatMap { offset in
            columns.map { CGPoint(x: $0, y: selection.maxY + offset) }.filter { window.contains($0) }
        }
    }

    mutating func read(selection: CGRect, window: CGRect) -> [CGRect] {
        for point in Self.probePoints(selection: selection, window: window).prefix(512) {
            guard backend.canContinue else { break }
            guard let hit = backend.hit(at: point) else { continue }
            var current: Backend.Node? = hit
            var chain: [Backend.Node] = []
            var envelope: CGRect?
            for _ in 0..<16 {
                guard backend.canContinue, let node = current, !chain.contains(node), !backend.isSecure(node) else { break }
                chain.append(node)
                let role = backend.role(of: node) ?? ""
                if ["AXWindow", "AXWebArea", "AXApplication"].contains(role) { break }
                // A previous probe with no candidate needn't repeat that subtree.
                if envelope == nil, examined.contains(node) { break }
                if !examined.contains(node) { examined.append(node) }
                if let rect = backend.bounds(of: node), window.intersects(rect),
                   SelectionPlacementEvidence.isNearbyMenu(rect, selection: selection),
                   isMenuSurface(node, role: role),
                   envelope.map({ rect.insetBy(dx: -2, dy: -2).contains($0) }) ?? true {
                    envelope = rect
                }
                current = backend.parent(of: node)
            }
            // Keep the largest compact actionable ancestor, including padding,
            // not just the first button hit. No app names or menu labels involved.
            if let envelope { return [envelope] }
        }
        return []
    }

    private func isMenuSurface(_ root: Backend.Node, role: String) -> Bool {
        if ["AXToolbar", "AXMenu"].contains(role) { return true }
        if ["AXButton", "AXMenuItem", "AXPopUpButton"].contains(role) { return true }
        guard ["AXGroup", "AXUnknown", "AXPopover"].contains(role) else { return false }
        var queue = [(root, 0)]
        var index = 0
        var visited: [Backend.Node] = []
        while index < queue.count, visited.count < 32, backend.canContinue {
            let (node, depth) = queue[index]
            index += 1
            guard !visited.contains(node), !backend.isSecure(node) else { continue }
            visited.append(node)
            let role = backend.role(of: node) ?? ""
            if ["AXButton", "AXMenuItem", "AXPopUpButton"].contains(role) { return true }
            if depth < 3, ["AXGroup", "AXUnknown", "AXPopover"].contains(role) {
                queue += backend.children(of: node, offset: 0, limit: 16).map { ($0, depth + 1) }
            }
        }
        return false
    }
}
