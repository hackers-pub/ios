import SwiftUI
import UIKit

@MainActor
enum ShareSheetPresenter {
    static func present(items: [Any], from view: UIView?) {
        guard !items.isEmpty else { return }
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view?.bounds ?? .zero
        }

        guard let presenter = topViewController(startingAt: view?.window?.rootViewController) else {
            return
        }
        presenter.present(activityViewController, animated: true)
    }

    private static func topViewController(startingAt root: UIViewController?) -> UIViewController? {
        guard let root else { return nil }

        if let presented = root.presentedViewController {
            return topViewController(startingAt: presented)
        }

        if let nav = root as? UINavigationController {
            return topViewController(startingAt: nav.visibleViewController)
        }

        if let tab = root as? UITabBarController {
            return topViewController(startingAt: tab.selectedViewController)
        }

        return root
    }
}
