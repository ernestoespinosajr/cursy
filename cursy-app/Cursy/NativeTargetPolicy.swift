/// A model cannot bypass native grounding by omitting a control ID.
enum NativeTargetPolicy {
    static func isValid(intent: String, controlID: String?) -> Bool {
        let suffixes = ["close_window": "-close", "minimize_window": "-minimize",
                        "zoom_window": "-zoom", "dock_application": "-dockapp"]
        if let suffix = suffixes[intent] {
            return controlID?.hasSuffix(suffix) == true
        }
        return intent == "other" && (controlID ?? "").isEmpty
    }
}
