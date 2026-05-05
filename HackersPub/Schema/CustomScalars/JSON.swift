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
      let object = foundationObject(from: value)
      if JSONSerialization.isValidJSONObject(object),
         let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
         let string = String(data: data, encoding: .utf8) {
        return string
      }
      return String(describing: value)
    }

    private static func foundationObject(from value: JSONValue) -> Any {
      foundationObject(fromAny: value)
    }

    private static func foundationObject(fromAny value: Any) -> Any {
      if let object = value as? JSONObject {
        return object.mapValues { foundationObject(fromAny: $0) }
      }
      if let object = value as? [AnyHashable: Any] {
        let pairs = object.map { key, value in
          (String(describing: key.base), foundationObject(fromAny: value))
        }
        return Dictionary(uniqueKeysWithValues: pairs)
      }
      if let object = value as? [String: Any] {
        return object.mapValues { foundationObject(fromAny: $0) }
      }
      if let array = value as? [Any] {
        return array.map { foundationObject(fromAny: $0) }
      }
      if let hashable = value as? AnyHashable {
        return hashable.base
      }
      if value is NSNull {
        return NSNull()
      }
      return value
    }

    private static func object(from value: JSONValue) -> JSONObject? {
      value as? JSONObject
    }
  }

}
