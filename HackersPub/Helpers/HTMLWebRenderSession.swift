import CoreGraphics
import Foundation

/// Identifies one concrete WebKit document load, even when its rendered inputs
/// are identical to a previous load.
struct HTMLWebRenderToken: Equatable {
    let generation: UInt64
    let contentKey: HTMLContentKey
}

/// Tracks the only navigation and script-message generation allowed to update
/// the current HTML view.
struct HTMLWebRenderSession {
    private(set) var activeToken: HTMLWebRenderToken?
    private var nextGeneration: UInt64 = 0
    private var activeNavigationIdentity: AnyObject?

    mutating func begin(for contentKey: HTMLContentKey) -> HTMLWebRenderToken {
        nextGeneration &+= 1
        let token = HTMLWebRenderToken(
            generation: nextGeneration,
            contentKey: contentKey
        )
        activeToken = token
        activeNavigationIdentity = nil
        return token
    }

    mutating func bindNavigationIdentity(
        _ navigationIdentity: AnyObject?,
        to token: HTMLWebRenderToken
    ) {
        guard activeToken == token, let navigationIdentity else { return }
        activeNavigationIdentity = navigationIdentity
    }

    func token(forFinishedNavigationIdentity navigationIdentity: AnyObject?) -> HTMLWebRenderToken? {
        guard let navigationIdentity,
              let activeNavigationIdentity,
              activeNavigationIdentity === navigationIdentity
        else {
            return nil
        }
        return activeToken
    }

    func accepts(_ token: HTMLWebRenderToken) -> Bool {
        activeToken == token
    }

    mutating func invalidate() {
        activeToken = nil
        activeNavigationIdentity = nil
    }
}

struct HTMLWebHeightMessage {
    let generation: UInt64
    let height: CGFloat

    init?(body: Any) {
        guard let payload = body as? [String: Any],
              let generation = Self.generation(from: payload["generation"]),
              let height = Self.height(from: payload["height"])
        else {
            return nil
        }

        self.generation = generation
        self.height = height
    }

    private static func generation(from value: Any?) -> UInt64? {
        if let value = value as? UInt64 {
            return value
        }
        if let value = value as? Int {
            return value >= 0 ? UInt64(value) : nil
        }
        guard let number = value as? NSNumber else { return nil }

        let value = number.doubleValue
        guard value.isFinite,
              value >= 0,
              value.rounded(.towardZero) == value,
              value <= Double(UInt64.max)
        else {
            return nil
        }
        return number.uint64Value
    }

    private static func height(from value: Any?) -> CGFloat? {
        guard let number = value as? NSNumber else { return nil }
        let height = CGFloat(number.doubleValue)
        return height.isFinite && height > 0 ? height : nil
    }
}
