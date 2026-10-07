import Foundation

/// An amount that may legitimately be absent (a null price means "free" in legacy data).
/// Accepts a string or number; missing/null/garbage → nil (garbage is reported).
@propertyWrapper
public struct LenientDecimal: Decodable, Sendable, Hashable {
    public var wrappedValue: Decimal?

    public init(wrappedValue: Decimal? = nil) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        guard let container = try? decoder.singleValueContainer(), !container.decodeNil() else {
            wrappedValue = nil
            return
        }
        if let text = try? container.decode(String.self) {
            wrappedValue = Decimal(string: text.trimmingCharacters(in: .whitespaces), locale: .posix)
            if wrappedValue == nil, !text.isEmpty {
                DecodingDiagnostics.report(DecodingIssue(
                    path: decoder.codingPath,
                    detail: "'\(text)' is not a decimal"
                ))
            }
        } else if let number = try? container.decode(Double.self) {
            wrappedValue = Decimal(string: String(number), locale: .posix)
        } else {
            DecodingDiagnostics.report(DecodingIssue(
                path: decoder.codingPath,
                detail: "expected decimal string or number"
            ))
            wrappedValue = nil
        }
    }
}

public extension KeyedDecodingContainer {
    func decode(_ type: LenientDecimal.Type, forKey key: Key) throws -> LenientDecimal {
        try decodeIfPresent(type, forKey: key) ?? LenientDecimal()
    }
}

/// Money fields. The API sends amounts as strings ("30.00") and occasionally as numbers;
/// both decode. Missing, null or unparsable → the response FAILS (guide, section 6):
/// a defaulted price of 0 would show "Free" and could check out at 0.
@propertyWrapper
public struct StrictDecimal: Decodable, Sendable, Hashable {
    public var wrappedValue: Decimal

    public init(wrappedValue: Decimal) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            guard let value = Decimal(
                string: text.trimmingCharacters(in: .whitespaces),
                locale: .posix
            ) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "'\(text)' is not a decimal amount"
                )
            }
            wrappedValue = value
            return
        }
        if let number = try? container.decode(Double.self) {
            // Round-trip through the textual form so 24.99 does not become 24.98999...
            guard let value = Decimal(string: String(number), locale: .posix) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "\(number) is not a decimal amount"
                )
            }
            wrappedValue = value
            return
        }
        throw DecodingError.typeMismatch(
            Decimal.self,
            .init(codingPath: decoder.codingPath, debugDescription: "amount must be a string or number")
        )
    }
}
