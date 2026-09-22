import CoreGraphics

/// Accepts only already-validated points/regions. One missing member suppresses
/// the entire step's group instead of drawing an incomplete drag/drop instruction.
enum WalkthroughAnnotations {
    struct Resolved {
        let indication: WalkthroughPlan.Indication
        let point: CGPoint
        let region: CGRect?
    }

    static func make(step: WalkthroughPlan.Step, resolved: [Resolved], displayFrame: CGRect) -> [VisualAnnotation] {
        guard resolved.count == step.indications.filter({ $0.role != .route }).count else { return [] }
        let annotations: [VisualAnnotation] = step.indications.compactMap { indication in
            if indication.role == .route {
                guard let source = resolved.first(where: { $0.indication.role == .source }),
                      let destination = resolved.first(where: { $0.indication.role == .destination }) else { return nil }
                return VisualAnnotation(style: .arrow, point: destination.point, displayFrame: displayFrame,
                    label: indication.caption, routeStart: source.point)
            }
            guard let item = resolved.first(where: { $0.indication == indication }) else { return nil }
            let style = VisualAnnotationStyle(rawValue: indication.kind.rawValue) ?? .cursor
            return VisualAnnotation(style: style, point: item.point, displayFrame: displayFrame,
                label: indication.caption, region: item.region)
        }
        return annotations.count == step.indications.count ? annotations : []
    }
}
