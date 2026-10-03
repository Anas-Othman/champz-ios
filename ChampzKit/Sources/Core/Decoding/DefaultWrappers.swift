import Foundation

// Lenient decoding for *cosmetic* fields (guide, section 6). A missing key or `null`
// becomes the default silently; a present value of the wrong type becomes the default
// AND is reported. IDs, money, statuses and logic-driving dates must never use these:
// they decode strictly so a broken payload fails loudly.

public protocol EmptyRepresentable {
    static var empty: Self { get }
}

extension String: EmptyRepresentable { public static var empty: String {
    ""
} }
extension Array: EmptyRepresentable { public static var empty: [Element] {
    []
} }
extension Dictionary: EmptyRepresentable { public static var empty: [Key: Value] {
    [:]
} }

/// Shared decode step: nil → fallback quietly; wrong type → fallback + report.
enum Lenient {
    static func decode<V: Decodable>(_: V.Type, from decoder: any Decoder, fallback: V) -> V {
        guard let container = try? decoder.singleValueContainer() else { return fallback }
        if container.decodeNil() {
            return fallback
        }
        do {
            return try container.decode(V.self)
        } catch {
            DecodingDiagnostics.report(DecodingIssue(path: decoder.codingPath, detail: "expected \(V.self): \(error)"))
            return fallback
        }
    }
}

/// `""`, `[]` or `[:]` when missing or null.
@propertyWrapper
public struct DefaultEmpty<Value: Decodable & EmptyRepresentable>: Decodable {
    public var wrappedValue: Value

    public init(wrappedValue: Value = .empty) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        wrappedValue = Lenient.decode(Value.self, from: decoder, fallback: .empty)
    }
}

/// `0` when missing or null.
@propertyWrapper
public struct DefaultZero<Value: Decodable & Numeric>: Decodable {
    public var wrappedValue: Value

    public init(wrappedValue: Value = .zero) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        wrappedValue = Lenient.decode(Value.self, from: decoder, fallback: .zero)
    }
}

/// `false` when missing or null.
@propertyWrapper
public struct DefaultFalse: Decodable {
    public var wrappedValue: Bool

    public init(wrappedValue: Bool = false) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        wrappedValue = Lenient.decode(Bool.self, from: decoder, fallback: false)
    }
}

/// An enum with an `unknown` case that absorbs values the app does not know yet,
/// so a new server value never crashes an old build.
public protocol UnknownCaseRepresentable: RawRepresentable, Decodable where RawValue: Decodable {
    static var unknown: Self { get }
}

/// `.unknown` when missing, null, or an unlisted raw value (the latter is reported).
@propertyWrapper
public struct DefaultUnknown<Value: UnknownCaseRepresentable>: Decodable {
    public var wrappedValue: Value

    public init(wrappedValue: Value = .unknown) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        guard let container = try? decoder.singleValueContainer(), !container.decodeNil() else {
            wrappedValue = .unknown
            return
        }
        guard let raw = try? container.decode(Value.RawValue.self) else {
            DecodingDiagnostics.report(DecodingIssue(
                path: decoder.codingPath,
                detail: "expected raw \(Value.RawValue.self)"
            ))
            wrappedValue = .unknown
            return
        }
        if let value = Value(rawValue: raw) {
            wrappedValue = value
        } else {
            DecodingDiagnostics.report(DecodingIssue(
                path: decoder.codingPath,
                detail: "unlisted \(Value.self) value '\(raw)'"
            ))
            wrappedValue = .unknown
        }
    }
}

extension DefaultEmpty: Sendable where Value: Sendable {}
extension DefaultZero: Sendable where Value: Sendable {}
extension DefaultFalse: Sendable {}
extension DefaultUnknown: Sendable where Value: Sendable {}

extension DefaultEmpty: Equatable where Value: Equatable {}
extension DefaultZero: Equatable where Value: Equatable {}
extension DefaultFalse: Equatable {}
extension DefaultUnknown: Equatable where Value: Equatable {}

extension DefaultEmpty: Hashable where Value: Hashable {}
extension DefaultZero: Hashable where Value: Hashable {}
extension DefaultFalse: Hashable {}
extension DefaultUnknown: Hashable where Value: Hashable {}

/// A missing key never reaches the wrapper's `init(from:)`; these overloads supply the default.
public extension KeyedDecodingContainer {
    func decode<V>(_ type: DefaultEmpty<V>.Type, forKey key: Key) throws -> DefaultEmpty<V> {
        try decodeIfPresent(type, forKey: key) ?? DefaultEmpty()
    }

    func decode<V>(_ type: DefaultZero<V>.Type, forKey key: Key) throws -> DefaultZero<V> {
        try decodeIfPresent(type, forKey: key) ?? DefaultZero()
    }

    func decode(_ type: DefaultFalse.Type, forKey key: Key) throws -> DefaultFalse {
        try decodeIfPresent(type, forKey: key) ?? DefaultFalse()
    }

    func decode<V>(_ type: DefaultUnknown<V>.Type, forKey key: Key) throws -> DefaultUnknown<V> {
        try decodeIfPresent(type, forKey: key) ?? DefaultUnknown()
    }
}
