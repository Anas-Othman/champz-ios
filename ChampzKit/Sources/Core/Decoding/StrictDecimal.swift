import Foundation

/// Money fields. The API sends amounts as strings ("30.00") and occasionally as numbers;
/// both decode. Missing, null or unparsable → the response FAILS (guide, section 6):
/// a defaulted price of 0 would show "Free" and could check out at 0.
@propertyWrapper
public struct StrictDecimal: Decodable, Sendable, Equatable {
    public var wrappedValue: Decimal

    public init(wrappedValue: Decimal) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            guard let value = Decimal(
                string: text.trimmingCharacters(in: .whitespaces),
                locale: Locale(identifier: "en_US_POSIX")
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
            guard let value = Decimal(string: String(number), locale: Locale(identifier: "en_US_POSIX")) else {
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
