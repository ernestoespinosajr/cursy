import Foundation
import CoreGraphics

/// The production AX adapter and offline fixtures execute the same traversal.
protocol SelectionSearchBackend {
    associatedtype Node: Equatable
    nonisolated var canContinue: Bool { get }
    nonisolated func parent(of node: Node) -> Node?
    nonisolated func children(of node: Node, offset: Int, limit: Int) -> [Node]
    nonisolated func role(of node: Node) -> String?
    nonisolated func isSecure(_ node: Node) -> Bool
    nonisolated func selectedText(in node: Node, anchor: CGPoint?) -> (SelectedTextContext, CGRect)?
}

nonisolated struct SelectionTreeSearch<Backend: SelectionSearchBackend> {
    let backend: Backend
    private(set) var visitedCount = 0
    private(set) var reachedLimit = false
    private var sampled: [Backend.Node] = []
    private let nodeLimit = 512

    init(backend: Backend) { self.backend = backend }

    mutating func read(window: Backend.Node, hit: Backend.Node?, focused: Backend.Node?,
                       anchor: CGPoint?) -> (SelectedTextContext, CGRect)? {
        let hitChain = ancestry(hit, stoppingAt: window)
        let focusChain = ancestry(focused, stoppingAt: window)
        // Do not fall through from a protected input into its document.
        guard !hitChain.contains(where: backend.isSecure), !focusChain.contains(where: backend.isSecure) else { return nil }
        // The enclosing web area owns cross-node ranges even when a toolbar has
        // focus. Query it before individual fragments, which may be partial.
        let candidates = (hitChain + focusChain).filter { backend.role(of: $0) == "AXWebArea" } + hitChain + focusChain
        for node in candidates {
            if let result = sample(node, anchor: anchor) { return result }
        }
        // DFS reaches documents behind deeply nested shells; pages ensure later
        // siblings aren't silently excluded by a fixed first-16-children slice.
        var stack: [(node: Backend.Node, depth: Int, offset: Int)] = [(window, 0, 0)]
        var expanded: [Backend.Node] = []
        while let entry = stack.popLast(), backend.canContinue {
            if entry.offset == 0 {
                guard !expanded.contains(entry.node), !backend.isSecure(entry.node) else { continue }
                guard expanded.count < nodeLimit else { reachedLimit = true; break }
                expanded.append(entry.node)
                let role = backend.role(of: entry.node) ?? ""
                if ["AXWebArea", "AXTextArea", "AXTextField", "AXStaticText", "AXText", "AXDocument", "AXComboBox"].contains(role),
                   let result = sample(entry.node, anchor: anchor) { return result }
                if ["AXMenu", "AXMenuBar", "AXToolbar"].contains(role) { continue }
            }
            guard entry.depth < 40, entry.offset < nodeLimit else { reachedLimit = true; continue }
            let children = backend.children(of: entry.node, offset: entry.offset, limit: 32)
            if children.count == 32 { stack.append((entry.node, entry.depth, entry.offset + 32)) }
            stack += children.reversed().map { ($0, entry.depth + 1, 0) }
        }
        return nil
    }

    private func ancestry(_ root: Backend.Node?, stoppingAt window: Backend.Node) -> [Backend.Node] {
        var chain: [Backend.Node] = []
        var current = root
        while let node = current, backend.canContinue, chain.count < 48, !chain.contains(node) {
            chain.append(node)
            if node == window || backend.isSecure(node) { break }
            current = backend.parent(of: node)
        }
        // Never search ancestors outside the originating window.
        return chain.last == window || chain.contains(where: backend.isSecure) ? chain : []
    }

    private mutating func sample(_ node: Backend.Node, anchor: CGPoint?) -> (SelectedTextContext, CGRect)? {
        guard backend.canContinue, !sampled.contains(node) else { return nil }
        sampled.append(node)
        visitedCount += 1
        return backend.selectedText(in: node, anchor: anchor)
    }
}

/// A successful setter is a request, not proof the remote tree is ready.
nonisolated struct SelectionAccessibilityWarmup {
    private var requestedAt: [Int32: TimeInterval] = [:]
    mutating func prepare(processID: Int32, now: TimeInterval, isEnabled: () -> Bool,
                          isSettable: () -> Bool, enable: () -> Bool) -> TimeInterval {
        if isEnabled() { return now }
        if let previous = requestedAt[processID], now - previous < 30 { return max(now, previous + 2.3) }
        guard isSettable(), enable() else { return now }
        if requestedAt.count >= 32 { requestedAt.removeAll() }
        requestedAt[processID] = now
        return now + 2.3
    }
}

/// Coalesces AX bursts without cancelling a lookup already bound to a gesture.
nonisolated struct SelectionReadLifecycle {
    private(set) var generation = UUID()
    private(set) var isReading = false
    mutating func begin() -> UUID? {
        guard !isReading else { return nil }
        isReading = true
        return generation
    }
    mutating func finish(_ token: UUID) -> Bool {
        guard token == generation else { return false }
        isReading = false
        return true
    }
    mutating func invalidate() { generation = UUID(); isReading = false }
}
