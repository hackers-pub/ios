enum NewsToolbarPolicy {
    static func showsSettings(isAuthenticated _: Bool) -> Bool {
        true
    }

    static func showsProfile(isAuthenticated: Bool) -> Bool {
        isAuthenticated
    }

    static func showsAdmin(isAuthenticated: Bool, isModerator: Bool) -> Bool {
        isAuthenticated && isModerator
    }
}
