// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

import Foundation
@_spi(Internal) @_spi(Execution) import ApolloAPI

public extension HackersPub {
  /// The `JSON` scalar type represents JSON values as specified by [ECMA-404](http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf).
  struct JSON: CustomScalarType {
    public let value: JSONValue
    private let canonicalValue: String

    public init(_jsonValue value: JSONValue) throws {
      self.value = value
      self.canonicalValue = Self.canonicalString(from: value)
    }

    public init(value: JSONValue) {
      self.value = value
      self.canonicalValue = Self.canonicalString(from: value)
    }

    public init(encodableDictionary: JSONEncodableDictionary) {
      let value = encodableDictionary._jsonValue
      self.value = value
      self.canonicalValue = Self.canonicalString(from: value)
    }

    @_spi(Internal) public var _jsonValue: JSONValue {
      value
    }

    public static func == (lhs: JSON, rhs: JSON) -> Bool {
      lhs.canonicalValue == rhs.canonicalValue
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(canonicalValue)
    }

    public var jsonObject: JSONObject? {
      Self.object(from: value)
    }

    public var stringValue: String? {
      value as? String
    }

    private static func canonicalString(from value: JSONValue) -> String {
      JSONCanonicalizationPolicy.canonicalString(fromAny: value)
    }

    private static func object(from value: JSONValue) -> JSONObject? {
      value as? JSONObject
    }
  }

}

enum JSONDictionaryKeyValidation: Equatable {
  case valid
  case stringifiedKeyCollision
}

enum JSONCanonicalizationPolicy {
  static func canonicalString(fromAny value: Any) -> String {
    if let object = foundationObject(fromAny: value),
       let data = try? JSONSerialization.data(
         withJSONObject: object,
         options: [.fragmentsAllowed, .sortedKeys]
       ),
       let string = String(data: data, encoding: .utf8) {
      return string
    }

    return "invalid-json:" + fallbackCanonicalString(fromAny: value)
  }

  static func dictionaryKeyValidation(
    for object: [AnyHashable: Any]
  ) -> JSONDictionaryKeyValidation {
    let keys = object.map { String(describing: $0.key.base) }
    return Set(keys).count == keys.count ? .valid : .stringifiedKeyCollision
  }

  private static func foundationObject(fromAny value: Any) -> Any? {
    if let object = value as? JSONObject {
      return foundationDictionary(from: object)
    }
    if let object = value as? [String: Any] {
      return foundationDictionary(from: object)
    }
    if let object = value as? [AnyHashable: Any] {
      guard dictionaryKeyValidation(for: object) == .valid else {
        return nil
      }

      var result: [String: Any] = [:]
      for (key, value) in object {
        guard let convertedValue = foundationObject(fromAny: value) else {
          return nil
        }
        result[String(describing: key.base)] = convertedValue
      }
      return result
    }
    if let array = value as? [Any] {
      let values = array.map { foundationObject(fromAny: $0) }
      guard values.allSatisfy({ $0 != nil }) else {
        return nil
      }
      return values.compactMap { $0 }
    }
    if value is NSNull {
      return NSNull()
    }
    if let hashable = value as? AnyHashable {
      return hashable.base
    }
    return nil
  }

  private static func foundationDictionary<T>(from object: [String: T]) -> [String: Any]? {
    var result: [String: Any] = [:]
    for (key, value) in object {
      guard let convertedValue = foundationObject(fromAny: value) else {
        return nil
      }
      result[key] = convertedValue
    }
    return result
  }

  private static func fallbackCanonicalString(fromAny value: Any) -> String {
    if let object = value as? JSONObject {
      return fallbackDictionary(from: object)
    }
    if let object = value as? [String: Any] {
      return fallbackDictionary(from: object)
    }
    if let object = value as? [AnyHashable: Any] {
      let entries = object.map { key, value in
        let keyType = String(reflecting: type(of: key.base))
        let keyValue = String(reflecting: key.base)
        let entry = lengthPrefixed(keyType) + lengthPrefixed(keyValue) +
          lengthPrefixed(fallbackCanonicalString(fromAny: value))
        return entry
      }
      return "map[" + entries.sorted().joined() + "]"
    }
    if let array = value as? [Any] {
      return "array[" + array.map { lengthPrefixed(fallbackCanonicalString(fromAny: $0)) }.joined() + "]"
    }
    if value is NSNull {
      return "null"
    }

    let valueType = String(reflecting: type(of: value))
    let description = String(reflecting: value)
    return "value(" + lengthPrefixed(valueType) + lengthPrefixed(description) + ")"
  }

  private static func fallbackDictionary<T>(from object: [String: T]) -> String {
    let entries = object.map { key, value in
      lengthPrefixed(key) + lengthPrefixed(fallbackCanonicalString(fromAny: value))
    }
    return "object[" + entries.sorted().joined() + "]"
  }

  private static func lengthPrefixed(_ value: String) -> String {
    "\(value.utf8.count):\(value)"
  }
}
