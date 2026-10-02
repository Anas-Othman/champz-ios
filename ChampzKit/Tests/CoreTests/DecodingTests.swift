import Foundation
import Testing
@testable import Core

private enum Status: String, UnknownCaseRepresentable, Equatable {
    case open, closed, unknown
}

private struct Sample: Decodable, Equatable {
    let id: Int
    @StrictDecimal var price: Decimal
    @DefaultEmpty var title: String
    @DefaultEmpty var tags: [String]
    @DefaultZero var spotsLeft: Int
    @DefaultFalse var isFull: Bool
    @DefaultUnknown var status: Status
    @LossyArray var players: [Player]
}

private struct Player: Decodable, Equatable {
    let id: Int
    @DefaultEmpty var name: String
}

/// Thread-safe sink for diagnostics raised during a decode.
private final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private var issues: [DecodingIssue] = []
    func append(_ issue: DecodingIssue) {
        lock.withLock { issues.append(issue) }
    }

    var paths: [String] {
        lock.withLock { issues.map(\.path) }
    }
}

private func decode(_ json: String) throws -> Sample {
    try JSONDecoder.api().decode(Sample.self, from: Data(json.utf8))
}

@Suite(.serialized)
struct DecodingTests {
    init() {
        DecodingDiagnostics.reset()
    }

    @Test func fullPayloadDecodes() throws {
        let sample = try decode("""
        {"id": 7, "price": "30.00", "title": "Friday 5s", "tags": ["a"], "spots_left": 3,
         "is_full": true, "status": "open", "players": [{"id": 1, "name": "A"}]}
        """)
        #expect(sample.id == 7)
        #expect(sample.price == Decimal(string: "30.00"))
        #expect(sample.title == "Friday 5s")
        #expect(sample.spotsLeft == 3)
        #expect(sample.isFull)
        #expect(sample.status == .open)
        #expect(sample.players.map(\.id) == [1])
        #expect(sample.players.map(\.name) == ["A"])
    }

    @Test func missingAndNullCosmeticFieldsDefaultQuietly() throws {
        let sample = try decode("""
        {"id": 7, "price": 30, "title": null, "spots_left": null, "status": null}
        """)
        #expect(sample.title == "")
        #expect(sample.tags == [])
        #expect(sample.spotsLeft == 0)
        #expect(sample.isFull == false)
        #expect(sample.status == .unknown)
        #expect(sample.players == [])
        #expect(sample.price == 30)
    }

    @Test func wrongTypeDefaultsAndReports() throws {
        let reported = Collector()
        DecodingDiagnostics.install { issue in reported.append(issue) }
        let sample = try decode("""
        {"id": 7, "price": "5", "title": 12, "spots_left": "three", "status": "archived"}
        """)
        #expect(sample.title == "")
        #expect(sample.spotsLeft == 0)
        #expect(sample.status == .unknown)
        let paths = reported.paths.sorted()
        #expect(paths == ["spotsLeft", "status", "title"])
    }

    @Test func lossyArrayDropsBadElementsOnly() throws {
        let sample = try decode("""
        {"id": 1, "price": "1", "players": [{"id": 1}, {"id": "oops"}, {"id": 3, "name": null}]}
        """)
        #expect(sample.players.map(\.id) == [1, 3])
    }

    @Test func missingIDFails() {
        #expect(throws: DecodingError.self) {
            try decode("""
            {"price": "30.00"}
            """)
        }
    }

    @Test func missingOrBadMoneyFails() {
        #expect(throws: DecodingError.self) { try decode("""
        {"id": 1}
        """) }
        #expect(throws: DecodingError.self) { try decode("""
        {"id": 1, "price": null}
        """) }
        #expect(throws: DecodingError.self) { try decode("""
        {"id": 1, "price": "free"}
        """) }
    }

    @Test func numericMoneyKeepsTwoDecimals() throws {
        let sample = try decode("""
        {"id": 1, "price": 24.99}
        """)
        #expect(sample.price == Decimal(string: "24.99"))
    }

    @Test func datesParseInEveryServerShape() {
        #expect(Date.parseAPI("2026-10-02T18:30:00.123Z") != nil)
        #expect(Date.parseAPI("2026-10-02T18:30:00Z") != nil)
        #expect(Date.parseAPI("2026-10-02T18:30:00+03:00") != nil)
        #expect(Date.parseAPI("2026-10-02") != nil)
        #expect(Date.parseAPI("yesterday") == nil)
    }
}
