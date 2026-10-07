import Foundation

/// Endpoints under /api/v1/profile/ and the reference lists the profile form uses.
enum ProfileAPI {
    static func profile() -> Endpoint<PlayerProfile> {
        Endpoint(.get, "/api/v1/profile/")
    }

    static func update(_ update: ProfileUpdate) -> Endpoint<PlayerProfile> {
        Endpoint(.patch, "/api/v1/profile/")
            .multipart(update.fields, file: update.avatar.map { .jpeg($0, name: "avatar") })
    }

    static func stats(_ id: PlayerID) -> Endpoint<PlayerStats> {
        Endpoint(.get, "/api/v1/players/\(id.raw)/stats/")
    }

    static func positions() -> Endpoint<[Position]> {
        Endpoint(.get, "/api/v1/positions/")
    }

    static func nationalities() -> Endpoint<[Nationality]> {
        Endpoint(.get, "/api/v1/countries/")
    }
}

public protocol ProfileRepository: Sendable {
    func profile() async throws(AppError) -> PlayerProfile
    /// Partial update; returns the saved profile.
    func update(_ update: ProfileUpdate) async throws(AppError) -> PlayerProfile
    func positions() async throws(AppError) -> [Position]
    func nationalities() async throws(AppError) -> [Nationality]
    /// Any player's card and statistics, including the signed-in player's own.
    func stats(_ id: PlayerID) async throws(AppError) -> PlayerStats
}

public struct LiveProfileRepository: ProfileRepository {
    let http: any HTTPClientProtocol

    public init(http: any HTTPClientProtocol) {
        self.http = http
    }

    public func profile() async throws(AppError) -> PlayerProfile {
        try await http.send(ProfileAPI.profile())
    }

    public func update(_ update: ProfileUpdate) async throws(AppError) -> PlayerProfile {
        try await http.send(ProfileAPI.update(update))
    }

    public func positions() async throws(AppError) -> [Position] {
        try await http.send(ProfileAPI.positions())
    }

    public func nationalities() async throws(AppError) -> [Nationality] {
        try await http.send(ProfileAPI.nationalities())
    }

    public func stats(_ id: PlayerID) async throws(AppError) -> PlayerStats {
        try await http.send(ProfileAPI.stats(id))
    }
}
