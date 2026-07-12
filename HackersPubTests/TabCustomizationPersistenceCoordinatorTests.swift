@testable import HackersPub
import Testing

private final class TabCustomizationPersistenceStoreSpy {
    typealias Context = TabCustomizationPersistenceContext

    private(set) var events: [String] = []
    var onRestore: ((Context) -> Void)?

    func persist(context: Context, value: String) {
        events.append("save:\(context.scope.rawValue)@\(context.epoch):\(value)")
    }

    func restore(context: Context) -> String {
        events.append("load:\(context.scope.rawValue)@\(context.epoch)")
        onRestore?(context)
        return "\(context.scope.rawValue)-customization"
    }
}

struct TabCustomizationPersistenceAdapterTests {
    typealias Adapter = TabCustomizationPersistenceAdapter<String>
    typealias Context = TabCustomizationPersistenceContext

    @Test func adapterFlushesTheOldContextBeforeRestoringTheNewContext() {
        let store = TabCustomizationPersistenceStoreSpy()
        var adapter = makeAdapter(store: store)

        let authenticatedContext = adapter.transition(to: .authenticated)

        #expect(
            store.events == [
                "save:guest@1:guest-customization",
                "load:authenticated@2"
            ]
        )
        #expect(authenticatedContext == Context(scope: .authenticated, epoch: 2))
        #expect(adapter.activeContext == authenticatedContext)
        #expect(adapter.value == "authenticated-customization")
    }

    @Test func adapterRejectsAStaleContextWriteAfterTransition() {
        let store = TabCustomizationPersistenceStoreSpy()
        var adapter = makeAdapter(store: store)
        let guestContext = adapter.activeContext

        let authenticatedContext = adapter.transition(to: .authenticated)
        let staleWriteAccepted = adapter.apply(
            "stale-empty-customization",
            from: guestContext
        )

        #expect(!staleWriteAccepted)
        #expect(adapter.value == "authenticated-customization")
        #expect(
            store.events == [
                "save:guest@1:guest-customization",
                "load:authenticated@2"
            ]
        )

        let currentWriteAccepted = adapter.apply(
            "authenticated-update",
            from: authenticatedContext
        )

        #expect(currentWriteAccepted)
        #expect(adapter.value == "authenticated-update")
        #expect(store.events.last == "save:authenticated@2:authenticated-update")
    }

    @Test func adapterRejectsAStaleWriteAfterScopeABAReturn() {
        let store = TabCustomizationPersistenceStoreSpy()
        var adapter = makeAdapter(store: store, value: "guest-epoch-one")
        let guestEpochOne = adapter.activeContext

        let authenticatedEpochTwo = adapter.transition(to: .authenticated)
        let guestEpochThree = adapter.transition(to: .guest)
        let staleCompletion: (inout Adapter) -> Bool = { adapter in
            adapter.apply("stale-guest-epoch-one", from: guestEpochOne)
        }

        #expect(guestEpochOne == Context(scope: .guest, epoch: 1))
        #expect(authenticatedEpochTwo == Context(scope: .authenticated, epoch: 2))
        #expect(guestEpochThree == Context(scope: .guest, epoch: 3))
        #expect(!staleCompletion(&adapter))
        #expect(adapter.value == "guest-customization")
        #expect(
            store.events == [
                "save:guest@1:guest-epoch-one",
                "load:authenticated@2",
                "save:authenticated@2:authenticated-customization",
                "load:guest@3"
            ]
        )
    }

    @Test func sameScopeTransitionRejectsAStaleAsyncCompletion() {
        let store = TabCustomizationPersistenceStoreSpy()
        var adapter = makeAdapter(store: store)
        let guestEpochOne = adapter.activeContext
        let staleCompletion: (inout Adapter) -> Bool = { adapter in
            adapter.apply("stale-async-completion", from: guestEpochOne)
        }

        let guestEpochTwo = adapter.transition(to: .guest)

        #expect(guestEpochTwo == Context(scope: .guest, epoch: 2))
        #expect(store.events.isEmpty)
        #expect(!staleCompletion(&adapter))
        #expect(adapter.value == "guest-customization")
        let currentWriteAccepted = adapter.apply("current-write", from: guestEpochTwo)
        #expect(currentWriteAccepted)
        #expect(store.events == ["save:guest@2:current-write"])
    }

    @Test func restoreScheduledDelayedWriteKeepsItsOriginalContext() throws {
        let store = TabCustomizationPersistenceStoreSpy()
        var adapter = makeAdapter(store: store)
        let guestContext = adapter.activeContext
        var pendingWrite: (value: String, context: Context)?
        store.onRestore = { _ in
            pendingWrite = ("restore-delayed-write", guestContext)
        }

        adapter.transition(to: .authenticated)
        let delayedWrite = try #require(pendingWrite)
        let delayedWriteAccepted = adapter.apply(
            delayedWrite.value,
            from: delayedWrite.context
        )

        #expect(!delayedWriteAccepted)
        #expect(adapter.value == "authenticated-customization")
        #expect(
            store.events == [
                "save:guest@1:guest-customization",
                "load:authenticated@2"
            ]
        )
    }

    private func makeAdapter(
        store: TabCustomizationPersistenceStoreSpy,
        value: String = "guest-customization"
    ) -> Adapter {
        Adapter(
            scope: .guest,
            value: value,
            persist: { context, value in
                store.persist(context: context, value: value)
            },
            restore: { context in
                store.restore(context: context)
            }
        )
    }
}
