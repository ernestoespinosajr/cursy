import AppKit

extension Notification.Name {
    static let cursyDismissPanel = Notification.Name("cursyDismissPanel")
}

/// The status item and camera hover share one Home, never a second settings panel.
@MainActor
final class MenuBarPanelManager: NSObject {
    private var statusItem: NSStatusItem?
    private let homePanelController: HomePanelController
    private let selectionController: SelectedTextPanelController
    private var dismissPanelObserver: NSObjectProtocol?

    init(companionManager: CompanionManager) {
        homePanelController = HomePanelController(companionManager: companionManager)
        selectionController = SelectedTextPanelController(manager: companionManager)
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let icon = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "Cursy")
                ?? NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "Cursy")
            button.image = icon?.withSymbolConfiguration(.init(pointSize: 14, weight: .semibold))
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        homePanelController.startHoverMonitoring()
        selectionController.onOpenChat = { [weak self] in self?.homePanelController.show() }
        selectionController.start()
        dismissPanelObserver = NotificationCenter.default.addObserver(
            forName: .cursyDismissPanel, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.homePanelController.hide() }
        }
    }

    deinit {
        if let dismissPanelObserver { NotificationCenter.default.removeObserver(dismissPanelObserver) }
    }

    func showPanelOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.homePanelController.show()
        }
    }

    @objc private func statusItemClicked() {
        homePanelController.toggle()
    }
}
