import Foundation

/// An array that drops elements which fail to decode instead of failing the whole
/// response. Each dropped element is reported, so one bad row never blanks a screen
/// and the backend still hears about it.
@propertyWrapper
public struct LossyArray<Element: Decodable>: Decodable {
    public var wrappedValue: [Element]

    public init(wrappedValue: [Element] = []) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: any Decoder) throws {
        guard let outer = try? decoder.singleValueContainer(), !outer.decodeNil() else {
            wrappedValue = []
            return
        }
        guard var container = try? decoder.unkeyedContainer() else {
            DecodingDiagnostics.report(DecodingIssue(
                path: decoder.codingPath,
                detail: "expected array of \(Element.self)"
            ))
            wrappedValue = []
            return
        }
        var elements: [Element] = []
        while !container.isAtEnd {
            do {
                try elements.append(container.decode(Element.self))
            } catch {
                // Advance past the bad element; `Blank` decodes anything.
                _ = try? container.decode(Blank.self)
                DecodingDiagnostics.report(DecodingIssue(
                    path: decoder.codingPath + [IndexKey(container.currentIndex - 1)],
                    detail: "dropped \(Element.self): \(error)"
                ))
            }
        }
        wrappedValue = elements
    }

    private struct Blank: Decodable {
        init(from decoder: any Decoder) throws {}
    }

    private struct IndexKey: CodingKey {
        let intValue: Int?
        var stringValue: String {
            "[\(intValue ?? -1)]"
        }

        init(_ index: Int) {
            intValue = index
        }

        init?(intValue: Int) {
            self.intValue = intValue
        }

        init?(stringValue: String) {
            nil
        }
    }
}

extension LossyArray: Sendable where Element: Sendable {}
extension LossyArray: Equatable where Element: Equatable {}

public extension KeyedDecodingContainer {
    func decode<E>(_ type: LossyArray<E>.Type, forKey key: Key) throws -> LossyArray<E> {
        try decodeIfPresent(type, forKey: key) ?? LossyArray()
    }
}
