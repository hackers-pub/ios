import Foundation

struct CustomSchemeAuthority {
    let segment: String?

    init?(components: URLComponents) {
        if let encodedUser = components.percentEncodedUser {
            guard
                let encodedHost = components.percentEncodedHost,
                let user = Self.decodedComponent(encodedUser),
                let decodedHost = Self.decodedComponent(encodedHost),
                let host = CustomSchemeHost(decodedHost),
                user.hasPrefix("@"),
                user.count > 1,
                !user.dropFirst().contains("@")
            else { return nil }

            segment = "\(user)@\(host.value)"
            return
        }

        if let encodedHost = components.percentEncodedHost {
            guard
                let decodedHost = Self.decodedComponent(encodedHost),
                let host = CustomSchemeHost(decodedHost)
            else { return nil }
            segment = host.value
            return
        }

        segment = nil
    }

    private static func decodedComponent(_ encodedValue: String) -> String? {
        guard let decodedValue = encodedValue.removingPercentEncoding else { return nil }

        let bytes = Array(decodedValue.utf8)
        var index = 0
        while index < bytes.count {
            guard bytes[index] == 0x25 else {
                index += 1
                continue
            }
            guard
                index + 2 < bytes.count,
                isHexadecimalDigit(bytes[index + 1]),
                isHexadecimalDigit(bytes[index + 2])
            else { return nil }
            index += 3
        }

        return decodedValue
    }

    private static func isHexadecimalDigit(_ byte: UInt8) -> Bool {
        (0x30 ... 0x39).contains(byte) ||
            (0x41 ... 0x46).contains(byte) ||
            (0x61 ... 0x66).contains(byte)
    }
}

private struct CustomSchemeHost {
    private static let forbiddenCharacters = CharacterSet(charactersIn: "@:/?#\\")
        .union(.whitespacesAndNewlines)
        .union(.controlCharacters)

    let value: String

    init?(_ value: String) {
        guard
            !value.isEmpty,
            value.unicodeScalars.allSatisfy({ !Self.forbiddenCharacters.contains($0) })
        else { return nil }

        self.value = value
    }
}
