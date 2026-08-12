@testable import HackersPub
import SwiftUI
import Testing

struct TabReselectionCoordinationTests {
    @Test("equal user selection reports a reselection without rewriting state")
    @MainActor
    func equalSelectionReportsReselection() {
        var selectedTab = "explore"
        var writes = [String]()
        var reselections = [String]()
        let binding = ActiveTabSelectionBindingAdapter(
            read: { selectedTab },
            writeBackingValue: {
                writes.append($0)
                selectedTab = $0
            },
            shouldHandleUserReselection: { _ in true },
            userReselected: { reselections.append($0) }
        ).binding

        binding.wrappedValue = "explore"

        #expect(reselections == ["explore"])
        #expect(writes.isEmpty)
        #expect(selectedTab == "explore")
    }

    @Test("a different selection uses the ordinary backing-state write")
    @MainActor
    func differentSelectionWritesState() {
        var selectedTab = "timeline"
        var reselections = [String]()
        let binding = ActiveTabSelectionBindingAdapter(
            read: { selectedTab },
            writeBackingValue: { selectedTab = $0 },
            shouldHandleUserReselection: { _ in true },
            userReselected: { reselections.append($0) }
        ).binding

        binding.wrappedValue = "explore"

        #expect(selectedTab == "explore")
        #expect(reselections.isEmpty)
    }

    @Test("an unsupported equal selection keeps the native binding path")
    @MainActor
    func unsupportedEqualSelectionWritesState() {
        var selectedTab = "timeline"
        var writes = [String]()
        var reselections = [String]()
        let binding = ActiveTabSelectionBindingAdapter(
            read: { selectedTab },
            writeBackingValue: {
                writes.append($0)
                selectedTab = $0
            },
            shouldHandleUserReselection: { _ in false },
            userReselected: { reselections.append($0) }
        ).binding

        binding.wrappedValue = "timeline"

        #expect(writes == ["timeline"])
        #expect(reselections.isEmpty)
    }
}
