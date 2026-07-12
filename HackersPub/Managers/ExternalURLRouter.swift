import Foundation
import SwiftUI
import UIKit

struct InAppBrowserDestination: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

struct BrowserPresentationCoordinator {
    private(set) var activeDestination: InAppBrowserDestination?
    private(set) var queuedDestinations: [InAppBrowserDestination] = []

    var destination: InAppBrowserDestination? {
        activeDestination
    }

    mutating func enqueue(_ destination: InAppBrowserDestination) {
        if activeDestination == nil {
            activeDestination = destination
        } else {
            queuedDestinations.append(destination)
        }
    }

    @discardableResult
    mutating func dismissed(presentationID: UUID) -> Bool {
        guard activeDestination?.id == presentationID else { return false }
        promoteNextDestination()
        return true
    }

    private mutating func promoteNextDestination() {
        activeDestination = queuedDestinations.isEmpty
            ? nil
            : queuedDestinations.removeFirst()
    }
}

@MainActor
struct BrowserSheetPresentation: Identifiable {
    let destination: InAppBrowserDestination
    let destinationBinding: Binding<InAppBrowserDestination?>
    private let onSheetDismiss: () -> Void

    var id: UUID {
        destination.id
    }

    init(
        destination: InAppBrowserDestination,
        destinationBinding: Binding<InAppBrowserDestination?>,
        onSheetDismiss: @escaping () -> Void
    ) {
        self.destination = destination
        self.destinationBinding = destinationBinding
        self.onSheetDismiss = onSheetDismiss
    }

    func onDismiss() {
        onSheetDismiss()
    }
}

@MainActor
final class BrowserSheetPresentationAdapter {
    private let router: ExternalURLRouter

    init(router: ExternalURLRouter) {
        self.router = router
    }

    var presentation: BrowserSheetPresentation? {
        guard let destination = router.destination else { return nil }
        let presentationID = destination.id

        return BrowserSheetPresentation(
            destination: destination,
            destinationBinding: Binding(
                get: {
                    guard self.router.destination?.id == presentationID else { return nil }
                    return self.router.destination
                },
                set: { destination in
                    guard destination == nil else { return }
                    self.router.dismissed(presentationID: presentationID)
                }
            ),
            onSheetDismiss: {
                self.router.dismissed(presentationID: presentationID)
            }
        )
    }
}

@MainActor
@Observable
final class ExternalURLRouter {
    static let shared = ExternalURLRouter()

    static let useInAppBrowserKey = "links.useInAppBrowser"

    private var browserPresentation = BrowserPresentationCoordinator()

    var destination: InAppBrowserDestination? {
        browserPresentation.destination
    }

    var useInAppBrowser: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.useInAppBrowserKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.useInAppBrowserKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.useInAppBrowserKey)
        }
    }

    func open(_ url: URL) {
        switch ExternalURLOpeningPolicy.action(
            for: url,
            useInAppBrowser: useInAppBrowser
        ) {
        case .consumeOwnedScheme:
            return
        case .inAppBrowser:
            enqueueBrowser(url)
        case .systemOpen:
            UIApplication.shared.open(url)
        }
    }

    func openInApp(_ url: URL) {
        switch ExternalURLOpeningPolicy.action(
            for: url,
            useInAppBrowser: true,
            forceInAppBrowser: true
        ) {
        case .consumeOwnedScheme:
            return
        case .inAppBrowser:
            enqueueBrowser(url)
        case .systemOpen:
            UIApplication.shared.open(url)
        }
    }

    func dismissed(presentationID: UUID) {
        browserPresentation.dismissed(presentationID: presentationID)
    }

    private func enqueueBrowser(_ url: URL) {
        let destination = InAppBrowserDestination(url: url)
        browserPresentation.enqueue(destination)
    }
}
