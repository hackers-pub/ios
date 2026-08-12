import SwiftUI

/// Separates user-driven `TabView` writes from programmatic selection changes.
@MainActor
struct ActiveTabSelectionBindingAdapter {
    let read: () -> String
    let writeBackingValue: (String) -> Void
    let shouldHandleUserReselection: (String) -> Bool
    let userReselected: (String) -> Void

    var binding: Binding<String> {
        Binding(
            get: { read() },
            set: { value in
                if value == read(), shouldHandleUserReselection(value) {
                    userReselected(value)
                } else {
                    writeBackingValue(value)
                }
            }
        )
    }
}
