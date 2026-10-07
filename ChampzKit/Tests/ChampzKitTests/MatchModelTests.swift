import Foundation
import Testing
@testable import ChampzKit

struct MatchModelTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    @Test func detailDecodesWithDiscountAndTeams() throws {
        let match = try JSONDecoder.api().decode(Match.self, from: fixture("match_detail"))
        #expect(match.id == "01J9MATCH0000000000000001")
        #expect(match.matchType == .friendly)
        #expect(match.status == .scheduled)
        #expect(match.effectivePrice == Money(24, currency: "QAR"))
        #expect(match.price == 30)
        #expect(match.spotsLeft == 3)
        #expect(match.isAlmostFull)
        #expect(!match.isLastSpot)
        #expect(abs((match.coordinate?.latitude ?? 0) - 25.26) < 0.0001)
        #expect(match.teams.count == 2)
        #expect(match.createdBy?.name == "Anas")
        #expect(match.kickoff != nil)
    }

    @Test func badPlayerRowIsDroppedNotFatal() throws {
        let match = try JSONDecoder.api().decode(Match.self, from: fixture("match_detail"))
        let names = match.allPlayers.map(\.name)
        #expect(names == ["Omar", "Guest"])
        #expect(match.allPlayers[1].isGuest)
    }

    @Test func minimalListRowDecodes() throws {
        let json = #"{"id": "01J9X", "price": null, "status": 7}"#
        let match = try JSONDecoder.api().decode(Match.self, from: Data(json.utf8))
        #expect(match.isFree)
        #expect(match.status == .unknown)
        #expect(match.teams.isEmpty)
        #expect(match.kickoff == nil)
    }

    @Test func matchTypeFollowsTheBackendEnum() throws {
        let competitive = try JSONDecoder.api().decode(Match.self, from: Data(#"{"id": "a", "match_type": 1}"#.utf8))
        let friendly = try JSONDecoder.api().decode(Match.self, from: Data(#"{"id": "b", "match_type": 2}"#.utf8))
        #expect(competitive.isCompetitive)
        #expect(friendly.matchType == .friendly)
    }

    @Test func rosterLayoutFollowsTypeAndTeamsDealt() throws {
        func decode(_ json: String) throws -> Match {
            try JSONDecoder.api().decode(Match.self, from: Data(json.utf8))
        }
        #expect(try decode(#"{"id": "a", "type": 0}"#).rosterLayout == .teamSheet)
        #expect(try decode(#"{"id": "a", "type": 0, "automatic_teams_created": true}"#).rosterLayout == .teamSheet)
        #expect(try decode(#"{"id": "a", "type": 1}"#).rosterLayout == .allPlayers)
        #expect(try decode(#"{"id": "a", "type": 1, "automatic_teams_created": false}"#).rosterLayout == .allPlayers)
        #expect(try decode(#"{"id": "a", "type": 1, "automatic_teams_created": true}"#).rosterLayout == .groupedByTeam)
    }

    @Test func missingIDFails() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder.api().decode(Match.self, from: Data(#"{"title": "x"}"#.utf8))
        }
    }

    @Test func primaryActionFollowsTheStatusRules() throws {
        var match = try JSONDecoder.api().decode(Match.self, from: fixture("match_detail"))
        #expect(match.primaryAction == .join)

        match.joinStatus = true
        #expect(match.primaryAction == .leave)

        match.joinStatus = false
        match.isJoinWaitingList = true
        #expect(match.primaryAction == .leaveWaitingList)

        match.isJoinWaitingList = false
        match.slotStatus = .waitingList
        #expect(match.primaryAction == .joinWaitingList)

        match.slotStatus = .full
        #expect(match.primaryAction == .full)
    }

    @Test func paginatedEnvelopeKnowsWhenThereIsMore() throws {
        let lastJSON = #"{"count": 1, "next": null, "results": [{"id": "a"}]}"#
        let last = try JSONDecoder.api().decode(PaginatedResponse<Match>.self, from: Data(lastJSON.utf8))
        #expect(last.pageResult(for: .first).next == nil)
        let moreJSON = #"{"count": 40, "next": "https://x/?page=2", "results": [{"id": "a"}, {"bad": true}]}"#
        let more = try JSONDecoder.api().decode(PaginatedResponse<Match>.self, from: Data(moreJSON.utf8))
        let page = more.pageResult(for: .first)
        #expect(page.next == Page(number: 2, size: 20))
        #expect(page.items.count == 1)
    }

    @Test func listEndpointBuildsTheQuery() {
        let filter = MatchFilter(dates: .range(from: "2026-10-01", to: "2026-10-07"), competition: .competitive)
        let endpoint = MatchesAPI.list(filter, page: Page(number: 2, size: 10))
        let query = Dictionary(uniqueKeysWithValues: endpoint.query.map { ($0.name, $0.value ?? "") })
        let expected = [
            "page": "2",
            "page_size": "10",
            "match_type": "1",
            "date_from": "2026-10-01",
            "date_to": "2026-10-07",
        ]
        #expect(query == expected)
        #expect(MatchesAPI.list(.default, page: .first).query.map(\.name).sorted() == ["page", "page_size"])
    }

    @Test func compactMoneyReadsLikeTheCurrentApp() throws {
        #expect(Money(30, currency: "QAR").compact == "30 QR")
        #expect(try Money(#require(Decimal(string: "24.50")), currency: "QAR").compact == "24.5 QR")
        #expect(try Money(#require(Decimal(string: "24.99")), currency: "QAR").compact == "24.99 QR")
    }
}
